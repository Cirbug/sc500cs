// Single red target, sampled connected components and image-centering commands.
// Two frame masks and a flood-fill stack map to ERAM, not pixel registers.
// A nominal 15% target is tested with 5% acquisition / 3% retention thresholds.
// Direction: 0=hold, 1=left/up, 2=right/down. Level: 0..3 (not servo degrees).
module red_target_tracker #(
    parameter integer IMG_WIDTH = 1920,
    parameter integer IMG_HEIGHT = 1080,
    parameter integer SAMPLE_SHIFT = 4,
    parameter integer ACQUIRE_PERCENT = 5,
    parameter integer RETAIN_PERCENT = 3,
    parameter integer CONFIRM_FRAMES = 3,
    parameter integer LOST_FRAMES = 5,
    parameter integer DEAD_X_ENTER = 32,
    parameter integer DEAD_X_EXIT = 48,
    parameter integer DEAD_Y_ENTER = 24,
    parameter integer DEAD_Y_EXIT = 36,
    parameter integer LEVEL_X_MEDIUM = 160,
    parameter integer LEVEL_X_LARGE = 400,
    parameter integer LEVEL_Y_MEDIUM = 120,
    parameter integer LEVEL_Y_LARGE = 300,
    // Display-only percentage conversion; raw area still drives association.
    parameter integer REPORT_AREA_PERCENT = 1
)(
    input wire I_clk, I_rst_n, I_enable, I_reacquire,
    input wire I_user, I_de,
    input wire [23:0] I_data,
    output reg O_new_result, O_valid,
    output reg [1:0] O_state, // 0=search, 1=locked, 2=lost
    output reg [11:0] O_x0, O_y0, O_x1, O_y1, O_cx, O_cy,
    output reg signed [12:0] O_error_x, O_error_y,
    output reg [1:0] O_dir_x, O_dir_y, O_level_x, O_level_y,
    output reg [6:0] O_area_percent
);
    localparam integer GW = (IMG_WIDTH + (1<<SAMPLE_SHIFT)-1) >> SAMPLE_SHIFT;
    localparam integer GH = (IMG_HEIGHT + (1<<SAMPLE_SHIFT)-1) >> SAMPLE_SHIFT;
    localparam integer XB = (GW>1) ? $clog2(GW) : 1;
    localparam integer YB = (GH>1) ? $clog2(GH) : 1;
    localparam integer AB = XB+YB;
    localparam integer CELLS = GW*GH;
    localparam integer SB = (CELLS>1) ? $clog2(CELLS) : 1;
    localparam integer ACQUIRE_MIN = (CELLS*ACQUIRE_PERCENT+99)/100;
    localparam integer RETAIN_MIN = (CELLS*RETAIN_PERCENT+99)/100;
    localparam integer CENTRE_X = IMG_WIDTH/2;
    localparam integer CENTRE_Y = IMG_HEIGHT/2;
    localparam [4:0] IDLE=0, SCAN_ADDR=1, SCAN_WAIT=2, SCAN_TEST=3,
        POP_ADDR=4, POP_WAIT=5, POP_LOAD=6, NEIGH_ADDR=7, NEIGH_WAIT=8,
        NEIGH_TEST=9, COMPONENT_CALC=10, COMPONENT_SCORE=11,
        PUBLISH=12, ERROR_CALC=13, COMMAND=14, PERCENT=15, FINISH=16, COMPONENT_CENTER=17;
    reg [4:0] state;
    reg [10:0] px, py;
    reg de_d, frame_started, capture_bank, scan_bank;
    reg [15:0] written;
    wire [XB-1:0] sample_x = px >> SAMPLE_SHIFT;
    wire [YB-1:0] sample_y = py >> SAMPLE_SHIFT;
    wire sample_pixel = I_enable && !I_reacquire && frame_started && !I_user &&
        I_de && ((px & ((1<<SAMPLE_SHIFT)-1))==0) &&
        ((py & ((1<<SAMPLE_SHIFT)-1))==0);
    wire [8:0] rr={1'b0,I_data[23:16]}, gg={1'b0,I_data[15:8]}, bb={1'b0,I_data[7:0]};
    wire is_red = (rr>=9'd80) && (rr>=gg+9'd32) && (rr>=bb+9'd32);
    (* ram_style="bram" *) reg mask0 [0:(1<<AB)-1];
    (* ram_style="bram" *) reg mask1 [0:(1<<AB)-1];
    reg [AB-1:0] mask_addr;
    reg mask_rd0, mask_rd1;
    wire mask_bit = scan_bank ? mask_rd1 : mask_rd0;
    wire clear_bit = (state==SCAN_TEST || state==NEIGH_TEST) && mask_bit;
    always @(posedge I_clk) begin
        mask_rd0 <= mask0[mask_addr];
        mask_rd1 <= mask1[mask_addr];
        if(sample_pixel && !capture_bank) mask0[{sample_y,sample_x}] <= is_red;
        else if(I_enable && !I_reacquire && clear_bit && !scan_bank) mask0[mask_addr] <= 1'b0;
        if(sample_pixel && capture_bank) mask1[{sample_y,sample_x}] <= is_red;
        else if(I_enable && !I_reacquire && clear_bit && scan_bank) mask1[mask_addr] <= 1'b0;
    end
    (* ram_style="bram" *) reg [AB-1:0] stack [0:(1<<SB)-1];
    reg [SB:0] stack_size;
    reg [SB-1:0] stack_addr;
    reg [AB-1:0] stack_rd;
    wire stack_push = I_enable && !I_reacquire && clear_bit;
    always @(posedge I_clk) begin
        stack_rd <= stack[stack_addr];
        if(stack_push) stack[stack_size[SB-1:0]] <= mask_addr;
    end

    reg [XB-1:0] scan_x, cur_x, comp_minx, comp_maxx;
    reg [YB-1:0] scan_y, cur_y, comp_miny, comp_maxy;
    reg [2:0] neighbour;
    reg [15:0] comp_area, best_area, previous_area;
    reg [11:0] cand_x0,cand_y0,cand_x1,cand_y1,cand_cx,cand_cy;
    reg [11:0] best_x0,best_y0,best_x1,best_y1,best_cx,best_cy;
    reg [11:0] previous_cx,previous_cy;
    reg [12:0] best_distance;
    reg locked;
    reg [3:0] confirmations, misses;
    reg [19:0] percent_remainder;
    reg [6:0] percent_value;
    wire [11:0] delta_x = (cand_cx>=previous_cx) ? cand_cx-previous_cx : previous_cx-cand_cx;
    wire [11:0] delta_y = (cand_cy>=previous_cy) ? cand_cy-previous_cy : previous_cy-cand_cy;
    wire [12:0] distance = {1'b0,delta_x}+{1'b0,delta_y};
    wire [11:0] acquire_dx = (best_cx>=previous_cx) ? best_cx-previous_cx : previous_cx-best_cx;
    wire [11:0] acquire_dy = (best_cy>=previous_cy) ? best_cy-previous_cy : previous_cy-best_cy;
    wire acquire_consistent = confirmations!=0 && acquire_dx<=IMG_WIDTH/8 &&
        acquire_dy<=IMG_HEIGHT/8 && {1'b0,best_area}<=({1'b0,previous_area}<<1) &&
        best_area>=(previous_area>>1);
    wire [12:0] abs_ex = O_error_x[12] ? -O_error_x : O_error_x;
    wire [12:0] abs_ey = O_error_y[12] ? -O_error_y : O_error_y;
    wire stop_x = abs_ex <= ((O_dir_x==0) ? DEAD_X_EXIT : DEAD_X_ENTER);
    wire stop_y = abs_ey <= ((O_dir_y==0) ? DEAD_Y_EXIT : DEAD_Y_ENTER);
    wire [12:0] sum_filter_x = {1'b0,O_cx}+{1'b0,best_cx};
    wire [12:0] sum_filter_y = {1'b0,O_cy}+{1'b0,best_cy};

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            px<=0; py<=0; de_d<=0; frame_started<=0; capture_bank<=0; scan_bank<=1;
            written<=0; state<=IDLE; mask_addr<=0; stack_addr<=0; stack_size<=0;
            scan_x<=0; scan_y<=0; cur_x<=0; cur_y<=0; neighbour<=0;
            comp_area<=0; comp_minx<=0; comp_maxx<=0; comp_miny<=0; comp_maxy<=0;
            best_area<=0; best_distance<=13'h1fff; previous_area<=0;
            best_x0<=0;best_y0<=0;best_x1<=0;best_y1<=0;best_cx<=0;best_cy<=0;
            cand_x0<=0;cand_y0<=0;cand_x1<=0;cand_y1<=0;cand_cx<=0;cand_cy<=0;
            previous_cx<=0;previous_cy<=0;locked<=0;confirmations<=0;misses<=0;
            percent_remainder<=0;percent_value<=0;
            O_new_result<=0;O_valid<=0;O_state<=0;
            O_x0<=0;O_y0<=0;O_x1<=0;O_y1<=0;O_cx<=CENTRE_X;O_cy<=CENTRE_Y;
            O_error_x<=0;O_error_y<=0;O_dir_x<=0;O_dir_y<=0;O_level_x<=0;O_level_y<=0;O_area_percent<=0;
        end else if(!I_enable || I_reacquire) begin
            px<=0;py<=0;de_d<=0;frame_started<=0;capture_bank<=0;scan_bank<=1;
            written<=0;state<=IDLE;stack_size<=0;locked<=0;confirmations<=0;misses<=0;
            O_new_result<=0;O_valid<=0;O_state<=0;O_dir_x<=0;O_dir_y<=0;
            O_level_x<=0;O_level_y<=0;O_error_x<=0;O_error_y<=0;O_area_percent<=0;
            O_cx<=CENTRE_X;O_cy<=CENTRE_Y;
        end else begin
            O_new_result<=0;
            de_d<=I_de;
            if(I_user) begin
                px<=0;py<=0;written<=0;frame_started<=1;
                // Only complete masks are handed to the scanner. Never reset ERAM.
                if(frame_started && written==CELLS && state==IDLE) begin
                    scan_bank<=capture_bank; capture_bank<=~capture_bank;
                    scan_x<=0;scan_y<=0;best_area<=0;best_distance<=13'h1fff;
                    state<=SCAN_ADDR;
                end
            end else if(I_de) begin
                if(px<IMG_WIDTH-1) px<=px+1'b1;
                if(sample_pixel) written<=written+1'b1;
            end else if(de_d) begin
                px<=0;
                if(py<IMG_HEIGHT-1) py<=py+1'b1;
            end
            case(state)
                IDLE: ;
                SCAN_ADDR: begin mask_addr<={scan_y,scan_x};state<=SCAN_WAIT;end
                SCAN_WAIT: state<=SCAN_TEST;
                SCAN_TEST: begin
                    if(mask_bit) begin
                        stack_size<=1;comp_area<=1;
                        comp_minx<=scan_x;comp_maxx<=scan_x;comp_miny<=scan_y;comp_maxy<=scan_y;
                        state<=POP_ADDR;
                    end else if(scan_x==GW-1) begin
                        scan_x<=0;
                        if(scan_y==GH-1) state<=PUBLISH;
                        else begin scan_y<=scan_y+1'b1;state<=SCAN_ADDR;end
                    end else begin scan_x<=scan_x+1'b1;state<=SCAN_ADDR;end
                end
                POP_ADDR: begin
                    if(stack_size==0) state<=COMPONENT_CALC;
                    else begin stack_addr<=stack_size-1'b1;stack_size<=stack_size-1'b1;state<=POP_WAIT;end
                end
                POP_WAIT: state<=POP_LOAD;
                POP_LOAD: begin cur_x<=stack_rd[XB-1:0];cur_y<=stack_rd[AB-1:XB];neighbour<=0;state<=NEIGH_ADDR;end
                NEIGH_ADDR: begin
                    if(neighbour==4) state<=POP_ADDR;
                    else if((neighbour==0 && cur_x==0) || (neighbour==1 && cur_x==GW-1) ||
                            (neighbour==2 && cur_y==0) || (neighbour==3 && cur_y==GH-1))
                        neighbour<=neighbour+1'b1;
                    else begin
                        case(neighbour)
                            0:mask_addr<={cur_y,cur_x}-1'b1;
                            1:mask_addr<={cur_y,cur_x}+1'b1;
                            2:mask_addr<={cur_y,cur_x}-(1<<XB);
                            3:mask_addr<={cur_y,cur_x}+(1<<XB);
                        endcase
                        state<=NEIGH_WAIT;
                    end
                end
                NEIGH_WAIT: state<=NEIGH_TEST;
                NEIGH_TEST: begin
                    if(mask_bit) begin
                        stack_size<=stack_size+1'b1;comp_area<=comp_area+1'b1;
                        if(mask_addr[XB-1:0]<comp_minx)comp_minx<=mask_addr[XB-1:0];
                        if(mask_addr[XB-1:0]>comp_maxx)comp_maxx<=mask_addr[XB-1:0];
                        if(mask_addr[AB-1:XB]<comp_miny)comp_miny<=mask_addr[AB-1:XB];
                        if(mask_addr[AB-1:XB]>comp_maxy)comp_maxy<=mask_addr[AB-1:XB];
                    end
                    neighbour<=neighbour+1'b1;state<=NEIGH_ADDR;
                end
                COMPONENT_CALC: begin
                    cand_x0<=comp_minx<<SAMPLE_SHIFT;cand_y0<=comp_miny<<SAMPLE_SHIFT;
                    cand_x1<=((comp_maxx<<SAMPLE_SHIFT)+((1<<SAMPLE_SHIFT)-1)<IMG_WIDTH) ?
                        (comp_maxx<<SAMPLE_SHIFT)+((1<<SAMPLE_SHIFT)-1) : IMG_WIDTH-1;
                    cand_y1<=((comp_maxy<<SAMPLE_SHIFT)+((1<<SAMPLE_SHIFT)-1)<IMG_HEIGHT) ?
                        (comp_maxy<<SAMPLE_SHIFT)+((1<<SAMPLE_SHIFT)-1) : IMG_HEIGHT-1;
                    state<=COMPONENT_CENTER;
                end
                COMPONENT_CENTER: begin
                    cand_cx<=({1'b0,cand_x0}+{1'b0,cand_x1})>>1;
                    cand_cy<=({1'b0,cand_y0}+{1'b0,cand_y1})>>1;
                    state<=COMPONENT_SCORE;
                end
                COMPONENT_SCORE: begin
                    if((!locked && comp_area>=ACQUIRE_MIN && comp_area>best_area) ||
                       (locked && comp_area>=RETAIN_MIN && delta_x<=IMG_WIDTH/4 && delta_y<=IMG_HEIGHT/4 &&
                        comp_area>=(previous_area>>1) && {1'b0,comp_area}<=({1'b0,previous_area}<<1) &&
                        (distance<best_distance || (distance==best_distance && comp_area>best_area)))) begin
                        best_area<=comp_area;best_distance<=distance;
                        best_x0<=cand_x0;best_y0<=cand_y0;best_x1<=cand_x1;best_y1<=cand_y1;
                        best_cx<=cand_cx;best_cy<=cand_cy;
                    end
                    // Rescan the seed once: it was cleared, so this advances normally.
                    state<=SCAN_ADDR;
                end
                PUBLISH: begin
                    if(REPORT_AREA_PERCENT)
                        percent_remainder<=({4'd0,best_area}<<6)+({4'd0,best_area}<<5)+({4'd0,best_area}<<2);
                    percent_value<=0;
                    if(best_area!=0) begin
                        previous_cx<=best_cx;previous_cy<=best_cy;previous_area<=best_area;misses<=0;
                        O_x0<=best_x0;O_y0<=best_y0;O_x1<=best_x1;O_y1<=best_y1;
                        if(locked || (acquire_consistent && confirmations>=CONFIRM_FRAMES-1) || CONFIRM_FRAMES==1) begin
                            O_valid<=1;O_state<=1;locked<=1;confirmations<=0;
                            O_cx<=locked ? sum_filter_x[12:1]+((best_cx>O_cx)&&sum_filter_x[0]) : best_cx;
                            O_cy<=locked ? sum_filter_y[12:1]+((best_cy>O_cy)&&sum_filter_y[0]) : best_cy;
                        end else begin
                            confirmations<=acquire_consistent ? confirmations+1'b1 : 1;
                            O_valid<=0;O_state<=0;
                        end
                    end else begin
                        O_valid<=0;confirmations<=0;O_state<=locked ? 2 : 0;
                        if(locked) begin
                            if(misses>=LOST_FRAMES-1) begin locked<=0;misses<=0;end
                            else misses<=misses+1'b1;
                        end
                    end
                    state<=ERROR_CALC;
                end
                ERROR_CALC: begin
                    O_error_x<=O_valid ? $signed({1'b0,O_cx})-CENTRE_X : 13'sd0;
                    O_error_y<=O_valid ? $signed({1'b0,O_cy})-CENTRE_Y : 13'sd0;
                    state<=COMMAND;
                end
                COMMAND: begin
                    O_dir_x<=(!O_valid || stop_x) ? 0 : (O_error_x[12] ? 1 : 2);
                    O_dir_y<=(!O_valid || stop_y) ? 0 : (O_error_y[12] ? 1 : 2);
                    O_level_x<=(!O_valid || stop_x) ? 0 : ((abs_ex>=LEVEL_X_LARGE) ? 3 : ((abs_ex>=LEVEL_X_MEDIUM) ? 2 : 1));
                    O_level_y<=(!O_valid || stop_y) ? 0 : ((abs_ey>=LEVEL_Y_LARGE) ? 3 : ((abs_ey>=LEVEL_Y_MEDIUM) ? 2 : 1));
                    state<=REPORT_AREA_PERCENT ? PERCENT : FINISH;
                end
                PERCENT: begin
                    if(REPORT_AREA_PERCENT) begin
                        if(percent_remainder>=CELLS) begin percent_remainder<=percent_remainder-CELLS;percent_value<=percent_value+1'b1;end
                        else begin O_area_percent<=percent_value;state<=FINISH;end
                    end else state<=FINISH;
                end
                FINISH: begin O_new_result<=1;state<=IDLE;end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
