`include "video_params.vh"
module video_out #(
    parameter integer FRAME_READ_WORDS=(`DISPLAY_WIDTH*`DISPLAY_HEIGHT*3)/16,
    parameter integer STRIDE=`DDR_FRAME_STRIDE_ADDR,
    parameter integer BURST=240
)(
    input wire I_rst_n,I_ddr_clk,
    output wire O_video_out_rd_busy,
    input wire I_video_in_wr_busy,
    input wire [1:0] I_video_out_rp,
    input wire I_video_out_valid,
    output reg [1:0] O_reader_bank,
    output reg O_reader_valid,
    output wire [31:0] O_display_diag,
    output wire O_ddr_user_rd_en,
    output reg [24:0] O_ddr_user_addr,
    input wire I_ddr_user_ready,I_ddr_user_rd_valid,
    input wire [127:0] I_ddr_user_rd_data,
    input wire I_dsi_clk,I_video_vsync,I_video_rd_en,
    output reg [23:0] O_vdieo_data
);
    (* ASYNC_REG="TRUE" *) reg [2:0] vs_sync;
    wire frame_start=vs_sync[1] && !vs_sync[2];
    // 0 drains old replies, 1 resets FIFO, 2 waits for FIFO reset release,
    // 3 reads a single fixed bank for this HDMI frame.
    reg [1:0] phase;
    reg [3:0] reset_count;
    reg burst_active;
    reg [8:0] burst_left;
    reg [19:0] issued;
    reg [9:0] pending;
    reg response_error;
    wire fifo_rst=!I_rst_n || phase==1;
    wire [8:0] fifo_used;
    wire fifo_full,S_fifo_emtpy;
    wire [10:0] reserved={2'd0,fifo_used}+{1'b0,pending};
    wire trigger_read=phase==3 && O_reader_valid && !frame_start && !burst_active &&
        !I_video_in_wr_busy && issued<FRAME_READ_WORDS && reserved<=511-BURST;
    assign O_video_out_rd_busy=trigger_read || burst_active;
    assign O_ddr_user_rd_en=phase==3 && !frame_start && burst_active && I_ddr_user_ready;
    wire response=I_ddr_user_rd_valid && pending!=0;
    wire [127:0] S_fifo_rd_data;
    wire S_fifo_rd_en,pixel_want;
    reg [3:0] S_fifo_rd_cnt,S_fifo_rd_cnt_1d;
    reg S_video_rd_en_1d;
    reg [127:0] S_fifo_rd_data_1d;
    reg pixel_bad,vs_pixel_d;
    reg [15:0] underflows;
    (* ASYNC_REG="TRUE" *) reg [1:0] frame_ready_sync;
    (* ASYNC_REG="TRUE" *) reg [1:0] response_error_sync;
    wire frame_ready=(phase==3 && O_reader_valid);
    wire pixel_underflow=pixel_want && frame_ready_sync[1] && !pixel_bad && S_fifo_emtpy;
    assign S_fifo_rd_en=pixel_want && frame_ready_sync[1] && !pixel_bad && !S_fifo_emtpy;
    assign O_display_diag={underflows,14'd0,response_error_sync[1],pixel_bad};

    function [24:0] bank_base(input [1:0] bank);
        case(bank) 0:bank_base=0;1:bank_base=STRIDE;default:bank_base=2*STRIDE;endcase
    endfunction
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            vs_sync<=0;phase<=0;reset_count<=0;burst_active<=0;burst_left<=0;
            issued<=0;pending<=0;O_reader_bank<=0;O_reader_valid<=0;
            O_ddr_user_addr<=0;response_error<=0;
        end else begin
            vs_sync<={vs_sync[1:0],I_video_vsync};
            case({O_ddr_user_rd_en,response})
                2'b10:pending<=pending+1'b1;
                2'b01:pending<=pending-1'b1;
            endcase
            if(I_ddr_user_rd_valid && pending==0) response_error<=1;
            if(response && phase==3 && fifo_full) response_error<=1;
            if(frame_start) begin
                phase<=0;burst_active<=0;
            end else case(phase)
                0: if(pending==0) begin
                    // No old-bank request/reply survives this bank change.
                    O_reader_bank<=I_video_out_rp;O_reader_valid<=I_video_out_valid;
                    O_ddr_user_addr<=bank_base(I_video_out_rp);issued<=0;
                    reset_count<=12;phase<=1;
                end
                1: if(reset_count==0) begin reset_count<=6;phase<=2;end
                   else reset_count<=reset_count-1'b1;
                2: if(reset_count==0) phase<=3;
                   else reset_count<=reset_count-1'b1;
                3: begin
                    if(trigger_read) begin
                        burst_active<=1;
                        if(FRAME_READ_WORDS-issued<BURST) burst_left<=FRAME_READ_WORDS-issued;
                        else burst_left<=BURST;
                    end
                    if(O_ddr_user_rd_en) begin
                        issued<=issued+1'b1;O_ddr_user_addr<=O_ddr_user_addr+25'd8;
                        burst_left<=burst_left-1'b1;
                        if(burst_left==1) burst_active<=0;
                    end
                end
            endcase
        end
    end
    w128_d512_fifo fifo(.rst(fifo_rst),.clkw(I_ddr_clk),
        .we(response && phase==3 && !fifo_full),.di(I_ddr_user_rd_data),
        .wrusedw(fifo_used),.full_flag(fifo_full),.afull(),.clkr(I_dsi_clk),
        .re(S_fifo_rd_en),.dout(S_fifo_rd_data),.rdusedw(),.valid(),
        .empty_flag(S_fifo_emtpy),.aempty());

    always @(posedge I_dsi_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            frame_ready_sync<=0;response_error_sync<=0;pixel_bad<=0;underflows<=0;vs_pixel_d<=0;
        end else begin
            frame_ready_sync<={frame_ready_sync[0],frame_ready};vs_pixel_d<=I_video_vsync;
            response_error_sync<={response_error_sync[0],response_error};
            if(I_video_vsync && !vs_pixel_d) pixel_bad<=0;
            else if(pixel_underflow || (I_video_rd_en && !frame_ready_sync[1])) begin
                if(!pixel_bad) underflows<=underflows+1'b1;
                pixel_bad<=1;
            end
        end
    end
   always @(posedge I_dsi_clk) begin
       if(I_video_rd_en)
           S_fifo_rd_cnt <= S_fifo_rd_cnt + 'd1;
       else
           S_fifo_rd_cnt <= 'd0;
   end

   assign pixel_want = I_video_rd_en && (S_fifo_rd_cnt == 'd0)  ? 1'b1 :
                         I_video_rd_en && (S_fifo_rd_cnt == 'd5)  ? 1'b1 :
                         I_video_rd_en && (S_fifo_rd_cnt == 'd10) ? 1'b1 : 1'b0;

   always @(posedge I_dsi_clk) begin
       S_video_rd_en_1d  <= I_video_rd_en;
       S_fifo_rd_cnt_1d  <= S_fifo_rd_cnt;
       S_fifo_rd_data_1d <= S_fifo_rd_data;
   end

   always @(posedge I_dsi_clk) begin
       if(S_video_rd_en_1d && !pixel_bad && frame_ready_sync[1])
           begin
               case(S_fifo_rd_cnt_1d)
                   'd0: O_vdieo_data  <= S_fifo_rd_data[127:104];
                   'd1: O_vdieo_data  <= S_fifo_rd_data[103:80];
                   'd2: O_vdieo_data  <= S_fifo_rd_data[79:56];
                   'd3: O_vdieo_data  <= S_fifo_rd_data[55:32];
                   'd4: O_vdieo_data  <= S_fifo_rd_data[31:8];
                   'd5: O_vdieo_data  <= {S_fifo_rd_data_1d[7:0],S_fifo_rd_data[127:112]};
                   'd6: O_vdieo_data  <= S_fifo_rd_data[111:88];
                   'd7: O_vdieo_data  <= S_fifo_rd_data[87:64];
                   'd8: O_vdieo_data  <= S_fifo_rd_data[63:40];
                   'd9: O_vdieo_data  <= S_fifo_rd_data[39:16];
                   'd10: O_vdieo_data <= {S_fifo_rd_data_1d[15:0],S_fifo_rd_data[127:120]};
                   'd11: O_vdieo_data <= S_fifo_rd_data[119:96];
                   'd12: O_vdieo_data <= S_fifo_rd_data[95:72];
                   'd13: O_vdieo_data <= S_fifo_rd_data[71:48];
                   'd14: O_vdieo_data <= S_fifo_rd_data[47:24];
                   'd15: O_vdieo_data <= S_fifo_rd_data[23:0];
               endcase
           end
       else
           O_vdieo_data <= 'd0;
   end

    
endmodule
