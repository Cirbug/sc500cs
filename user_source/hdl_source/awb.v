/* Frame-statistics AWB with confidence gating and frame-atomic gains.
 * One lane per four RGB pixels is sampled. Dark/clipped/high-chroma samples
 * cannot steer the estimate. A shared serial divider computes G/R and G/B;
 * completed candidates are committed at a later frame boundary, never mid-frame.
 * The pixel pipeline and all four gain multipliers retain their original latency.
 */
module awb #(
    parameter IMG_HEIGHT = 1080,
    parameter IMG_WIDTH  = 1920,
    parameter AWB_EN = 1'b1,
    parameter [19:0] AWB_FIXED_GAIN_R = 20'h10000,
    parameter [19:0] AWB_FIXED_GAIN_B = 20'h10000,
    // At least 1/64 of the expected lane-0 samples, and at least 16 samples.
    parameter integer MIN_VALID_SAMPLES =
        ((IMG_HEIGHT*IMG_WIDTH+255)/256 > 16) ? (IMG_HEIGHT*IMG_WIDTH+255)/256 : 16
)(
    input I_clk, I_rst_n, I_tlast, I_tuser,
    input [95:0] I_tdata,
    input I_tvalid,
    output I_tready,
    input I_bypass,
    input [7:0] I_blc_off,
    input I_gate_en,
    // Relative chroma threshold in Q0.8: 64 means (max-min)/max <= 1/4.
    input [7:0] I_gate_th,
    input I_smooth_en,
    output O_tlast, O_tuser,
    output [95:0] O_tdata,
    output O_tvalid,
    input O_tready
);
    function [7:0] sub_off;
        input [7:0] d, off;
        begin sub_off=(d>off) ? d-off : 8'd0; end
    endfunction
    wire [95:0] S_tdata_raw=I_tdata;
    wire [95:0] S_tdata={
        sub_off(I_tdata[95:88],I_blc_off),sub_off(I_tdata[87:80],I_blc_off),sub_off(I_tdata[79:72],I_blc_off),
        sub_off(I_tdata[71:64],I_blc_off),sub_off(I_tdata[63:56],I_blc_off),sub_off(I_tdata[55:48],I_blc_off),
        sub_off(I_tdata[47:40],I_blc_off),sub_off(I_tdata[39:32],I_blc_off),sub_off(I_tdata[31:24],I_blc_off),
        sub_off(I_tdata[23:16],I_blc_off),sub_off(I_tdata[15:8],I_blc_off),sub_off(I_tdata[7:0],I_blc_off)
    };
    wire S_awb_off=(~AWB_EN) | I_bypass;
    wire [18:0] config_live={I_blc_off,I_gate_th,I_gate_en,I_smooth_en,I_bypass};
    reg [18:0] frame_config;
    reg frame_dirty;
    reg I_tvalid_r0,I_tvalid_r1,sof_d0,sof_d1,raw_clipped_d0;
    reg [95:0] I_tdata_d0,I_tdata_d1;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            I_tdata_d0<=0;I_tdata_d1<=0;I_tvalid_r0<=0;I_tvalid_r1<=0;
            sof_d0<=0;sof_d1<=0;raw_clipped_d0<=0;
        end else begin
            I_tdata_d0<=S_tdata;I_tdata_d1<=I_tdata_d0;
            I_tvalid_r0<=I_tvalid;I_tvalid_r1<=I_tvalid_r0;
            sof_d0<=I_tuser;sof_d1<=sof_d0;
            // Check before black subtraction: clipped input must not become
            // an apparently safe sample simply by subtracting BLACK.
            raw_clipped_d0<=(I_tdata[23:16]>=8'd250) ||
                            (I_tdata[15:8]>=8'd250) || (I_tdata[7:0]>=8'd250);
        end
    end
    wire [7:0] r=I_tdata_d0[23:16],g=I_tdata_d0[15:8],b=I_tdata_d0[7:0];
    wire [7:0] mx=(r>g) ? ((r>b)?r:b) : ((g>b)?g:b);
    wire [7:0] mn=(r<g) ? ((r<b)?r:b) : ((g<b)?g:b);
    wire [7:0] chroma=mx-mn;
    // The production threshold is constant 64, hence this product reduces
    // to wiring/shifts in synthesis, not a new per-pixel divider or DSP.
    wire [15:0] gray_limit=mx*I_gate_th;
    wire S_stat_en=I_tvalid_r0 && !raw_clipped_d0 &&
        mx>=8'd32 && mx<=8'd240 && mn>=8'd8 && chroma<=(mx>>1) &&
        (!I_gate_en || {chroma,8'd0}<=gray_limit);

    localparam integer COUNT_W=$clog2((IMG_HEIGHT*IMG_WIDTH+3)/4+1);
    reg [COUNT_W-1:0] sample_count;
    reg [31:0] sum_r,sum_g,sum_b;
    // A frame containing a control change is not mixed with a different
    // BLACK/gating/mode profile. Zero denominators are checked before divide.
    wire frame_ok=!frame_dirty && frame_config==config_live &&
        sample_count>=MIN_VALID_SAMPLES && sum_r!=0 && sum_b!=0;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            sum_r<=0;sum_g<=0;sum_b<=0;sample_count<=0;
            frame_config<=0;frame_dirty<=1;
        end else if(sof_d0) begin
            // Include a valid first pixel even when SOF and valid coincide.
            sum_r<=S_stat_en ? {24'd0,r}:32'd0;
            sum_g<=S_stat_en ? {24'd0,g}:32'd0;
            sum_b<=S_stat_en ? {24'd0,b}:32'd0;
            sample_count<=S_stat_en ? 1:0;
            frame_config<=config_live;frame_dirty<=0;
        end else begin
            if(frame_config!=config_live) frame_dirty<=1;
            if(S_stat_en && !(&sample_count)) begin
                sum_r<=sum_r+r;sum_g<=sum_g+g;sum_b<=sum_b+b;
                sample_count<=sample_count+1'b1;
            end
        end
    end

    // Restoring divide: 48-bit numerator (sumG << 16), 32-bit denominator.
    // The stored remainder is < denominator; only its shifted compare needs
    // 33 bits. Shift in quotient bits instead of a variable 48-bit bit-mask.
    reg [31:0] lat_g,lat_b,div_den,div_rem;
    reg [18:0] lat_config;
    reg [47:0] div_num,div_quot;
    reg [19:0] calc_r;
    reg [5:0] div_cnt;
    reg [1:0] div_st;
    reg div_phase,div_done;
    wire [32:0] div_rem_sh={div_rem,div_num[47]};
    wire [32:0] div_den_ex={1'b0,div_den};
    wire div_ge=div_rem_sh>=div_den_ex;
    function [19:0] bounded_gain;
        input [47:0] q;
        begin
            if(q<48'h000000008000) bounded_gain=20'h08000;
            else if(q>48'h000000040000) bounded_gain=20'h40000;
            else bounded_gain=q[19:0];
        end
    endfunction
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            lat_g<=0;lat_b<=1;lat_config<=0;div_num<=0;div_den<=1;
            div_rem<=0;div_quot<=0;calc_r<=20'h10000;div_cnt<=0;
            div_st<=0;div_phase<=0;div_done<=0;
        end else begin
            div_done<=0;
            case(div_st)
            0: if(sof_d0 && frame_ok && !S_awb_off) begin
                lat_g<=sum_g;lat_b<=sum_b;lat_config<=frame_config;
                div_num<={sum_g,16'd0};div_den<=sum_r;
                div_rem<=0;div_quot<=0;div_cnt<=0;div_phase<=0;div_st<=1;
            end
            1: begin
                div_rem<=div_ge ? div_rem_sh-div_den_ex : div_rem_sh;
                div_quot<={div_quot[46:0],div_ge};
                div_num<={div_num[46:0],1'b0};
                if(div_cnt==47) div_st<=2;
                else div_cnt<=div_cnt+1'b1;
            end
            2: if(!div_phase) begin
                calc_r<=bounded_gain(div_quot);
                div_num<={lat_g,16'd0};div_den<=lat_b;
                div_rem<=0;div_quot<=0;div_cnt<=0;div_phase<=1;div_st<=1;
            end else begin div_done<=1;div_st<=0;end
            default: div_st<=0;
            endcase
        end
    end

    reg [19:0] pending_r,pending_b,in_r_r1,in_b_r1;
    reg [18:0] pending_config;
    reg pending_valid;
    wire signed [20:0] dif_r=$signed({1'b0,pending_r})-$signed({1'b0,in_r_r1});
    wire signed [20:0] dif_b=$signed({1'b0,pending_b})-$signed({1'b0,in_b_r1});
    wire signed [20:0] nxt_r=$signed({1'b0,in_r_r1})+(dif_r>>>3);
    wire signed [20:0] nxt_b=$signed({1'b0,in_b_r1})+(dif_b>>>3);
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            in_r_r1<=AWB_FIXED_GAIN_R;in_b_r1<=AWB_FIXED_GAIN_B;
            pending_r<=20'h10000;pending_b<=20'h10000;
            pending_config<=0;pending_valid<=0;
        end else begin
            // Align the gain boundary with data_d1, just before multiplication.
            // This also handles consecutive frames with no blanking gap.
            if(sof_d1) begin
                pending_valid<=0;
                if(S_awb_off) begin
                    in_r_r1<=AWB_FIXED_GAIN_R;in_b_r1<=AWB_FIXED_GAIN_B;
                end else if(pending_valid && pending_config==config_live) begin
                    in_r_r1<=I_smooth_en ? nxt_r[19:0] : pending_r;
                    in_b_r1<=I_smooth_en ? nxt_b[19:0] : pending_b;
                end
            end
            if(div_done && !S_awb_off && lat_config==config_live) begin
                pending_r<=calc_r;pending_b<=bounded_gain(div_quot);
                pending_config<=lat_config;pending_valid<=1;
            end
        end
    end

    // ---- 数据/有效信号流水（去掉 50 拍 BRAM 延迟线，仅 1 拍）----
    reg [95:0] data_d1;
    reg        valid_d1, valid_d2;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            valid_d1 <= 0;
            data_d1  <= 0;
            valid_d2 <= 0;
        end else begin
            valid_d1 <= I_tvalid_r1;
            data_d1  <= I_tdata_d1;
            valid_d2 <= valid_d1;
        end
    end

    wire [7:0] rgb888_r_d1[0:3];
    wire [7:0] rgb888_g_d1[0:3];
    wire [7:0] rgb888_b_d1[0:3];

    assign rgb888_r_d1[0] = data_d1[16+:8];
    assign rgb888_g_d1[0] = data_d1[8+:8];
    assign rgb888_b_d1[0] = data_d1[0+:8];
    assign rgb888_r_d1[1] = data_d1[40+:8];
    assign rgb888_g_d1[1] = data_d1[32+:8];
    assign rgb888_b_d1[1] = data_d1[24+:8];
    assign rgb888_r_d1[2] = data_d1[64+:8];
    assign rgb888_g_d1[2] = data_d1[56+:8];
    assign rgb888_b_d1[2] = data_d1[48+:8];
    assign rgb888_r_d1[3] = data_d1[88+:8];
    assign rgb888_g_d1[3] = data_d1[80+:8];
    assign rgb888_b_d1[3] = data_d1[72+:8];

    // ---- 增益应用（共享增益，4 个像素）----
    reg [27:0] R_new_r1, G_new_r1, B_new_r1;
    reg [27:0] R_new_r2, G_new_r2, B_new_r2;
    reg [27:0] R_new_r3, G_new_r3, B_new_r3;
    reg [27:0] R_new_r4, G_new_r4, B_new_r4;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            R_new_r1 <= 0; G_new_r1 <= 0; B_new_r1 <= 0;
            R_new_r2 <= 0; G_new_r2 <= 0; B_new_r2 <= 0;
            R_new_r3 <= 0; G_new_r3 <= 0; B_new_r3 <= 0;
            R_new_r4 <= 0; G_new_r4 <= 0; B_new_r4 <= 0;
        end
        else if (valid_d1) begin
            R_new_r1 <= in_r_r1 * rgb888_r_d1[0];
            G_new_r1 <=           rgb888_g_d1[0];
            B_new_r1 <= in_b_r1 * rgb888_b_d1[0];
            R_new_r2 <= in_r_r1 * rgb888_r_d1[1];
            G_new_r2 <=           rgb888_g_d1[1];
            B_new_r2 <= in_b_r1 * rgb888_b_d1[1];
            R_new_r3 <= in_r_r1 * rgb888_r_d1[2];
            G_new_r3 <=           rgb888_g_d1[2];
            B_new_r3 <= in_b_r1 * rgb888_b_d1[2];
            R_new_r4 <= in_r_r1 * rgb888_r_d1[3];
            G_new_r4 <=           rgb888_g_d1[3];
            B_new_r4 <= in_b_r1 * rgb888_b_d1[3];
        end
    end

    // ---- 截断到 8bit（饱和）----
    wire [7:0] R_new_x1 = (R_new_r1[27:24]) ? 255 : R_new_r1[23:16];
    wire [7:0] G_new_x1 = G_new_r1;
    wire [7:0] B_new_x1 = (B_new_r1[27:24]) ? 255 : B_new_r1[23:16];
    wire [7:0] R_new_x2 = (R_new_r2[27:24]) ? 255 : R_new_r2[23:16];
    wire [7:0] G_new_x2 = G_new_r2;
    wire [7:0] B_new_x2 = (B_new_r2[27:24]) ? 255 : B_new_r2[23:16];
    wire [7:0] R_new_x3 = (R_new_r3[27:24]) ? 255 : R_new_r3[23:16];
    wire [7:0] G_new_x3 = G_new_r3;
    wire [7:0] B_new_x3 = (B_new_r3[27:24]) ? 255 : B_new_r3[23:16];
    wire [7:0] R_new_x4 = (R_new_r4[27:24]) ? 255 : R_new_r4[23:16];
    wire [7:0] G_new_x4 = G_new_r4;
    wire [7:0] B_new_x4 = (B_new_r4[27:24]) ? 255 : B_new_r4[23:16];

    // ---- 输出（与原设计一致：O_tuser 直通、O_tlast 为 valid 下降沿）----
    assign O_tlast  = (valid_d1 == 0) && (valid_d2 == 1);
    assign O_tuser  = I_tuser;
    assign O_tvalid = valid_d2;
    assign O_tdata  = O_tvalid ? {R_new_x4, G_new_x4, B_new_x4,
                                  R_new_x3, G_new_x3, B_new_x3,
                                  R_new_x2, G_new_x2, B_new_x2,
                                  R_new_x1, G_new_x1, B_new_x1} : 0;
    assign I_tready = O_tready;

endmodule

