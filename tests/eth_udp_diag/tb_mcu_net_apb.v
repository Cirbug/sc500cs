`timescale 1ns/1ps

module tb_mcu_net_apb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg [19:0] addr = 20'd0;
    wire [31:0] prdata;
    reg [31:0] tx_packets=32'd11, tx_frames=32'd22;
    reg [31:0] replies=32'd33, bad=32'd44;
    reg [31:0] remote_frames=32'd55, remote_errors=32'd66;
    reg [31:0] remote_frame_id=32'd77;
    reg [4:0] net_status=5'h15;
    reg [15:0] stack_debug=16'h05a3;

    always #5 clk = ~clk;

    mcu_ui_apb_regs dut (
        .I_clk(clk), .I_rst(reset), .I_button(4'hf), .I_usb_int_n(1'b1),
        .I_paddr(addr), .I_psel(1'b1), .I_penable(1'b1), .I_pwrite(1'b0),
        .I_pwdata(32'd0), .I_pstrobe(4'd0), .O_prdata(prdata),
        .I_net_tx_packets(tx_packets), .I_net_tx_frames(tx_frames),
        .I_net_reply_packets(replies), .I_net_bad_packets(bad),
        .I_net_remote_frames(remote_frames), .I_net_remote_errors(remote_errors),
        .I_net_remote_frame_id(remote_frame_id), .I_net_status(net_status),
        .I_net_stack_debug(stack_debug)
    );

    task check(input [19:0] offset, input [31:0] expected);
        begin
            addr = offset;
            #1;
            if(prdata !== expected) begin
                $display("FAIL APB offset=%03x got=%08x expected=%08x",offset,prdata,expected);
                $fatal(1);
            end
        end
    endtask

    initial begin
        #12 reset=1'b0;
        check(20'h00100,32'h4e455431);
        check(20'h00104,32'd11);
        check(20'h00108,32'd22);
        check(20'h0010c,32'd33);
        check(20'h00110,32'd44);
        check(20'h00114,32'd55);
        check(20'h00118,32'd66);
        check(20'h0011c,32'd77);
        check(20'h00120,32'h15);
        check(20'h00124,32'h000005a3);
        $display("MCU_NET_APB_PASS id=NET1 tx=11/22 reply=33 bad=44 peer=55/66 id=77 status=15 stack=05a3");
        $finish;
    end
endmodule
