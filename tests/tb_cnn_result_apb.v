`timescale 1ns/1ps
module tb_cnn_result_apb;
    reg apb_clk=0,pixel_clk=0,rst_n=0;
    always #10 apb_clk=~apb_clk;
    always #6.67 pixel_clk=~pixel_clk;
    reg sel=0,en=0,wr=0;reg [7:0] addr=0;reg [3:0] strobe=0;reg [31:0] data=0;
    wire [31:0] rdata;wire overlay_enable;
    cnn_result_apb d(.apb_clk(apb_clk),.pixel_clk(pixel_clk),.rst_n(rst_n),
        .sel(sel),.enable(en),.write(wr),.addr(addr),.strobe(strobe),.wdata(data),.rdata(rdata),
        .overlay_enable(overlay_enable),.result_valid(1'b1),.result_overflow(1'b1),.result_count(5'd16),
        .result_sequence(16'habcd),.weight_crc(32'heec8e020),.good_packets(32'd1234),.bad_packets(32'd5));
    task read;
        input [7:0] off;input [31:0] expected;
        begin addr=off;#1;if(rdata!==expected)$fatal(1,"APB %h=%h expected %h",off,rdata,expected);end
    endtask
    initial begin
        #100;rst_n=1;repeat(30)@(negedge apb_clk);
        read(0,32'h53504447);read(4,0);read(8,32'habcd00c1);
        read(12,32'heec8e020);read(16,1234);read(20,5);read(24,32'h000101f4);
        if(overlay_enable)$fatal(1,"enabled at reset");
        addr=4;sel=1;en=1;wr=1;data=1;strobe=0;repeat(4)@(negedge apb_clk);
        if(overlay_enable)$fatal(1,"ignored byte strobes");
        strobe=1;repeat(4)@(negedge apb_clk);sel=0;
        if(!overlay_enable)$fatal(1,"menu enable did not cross");
        read(4,1);rst_n=0;#50;
        if(overlay_enable)$fatal(1,"reset failed");
        $display("CNN_APB_PASS ID/control/strobes/coherent-diagnostics/CDC/reset");$finish;
    end
endmodule
