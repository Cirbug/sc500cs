`timescale 1ns/1ps
module tb_red_tracking_osd;
    reg enable=1,de=1,valid=0;
    reg [11:0] x=0,y=0;
    wire hit;wire [23:0] color;
    red_tracking_osd dut(
        .I_clk(1'b0),.I_rst_n(1'b1),.I_enable(enable),.I_de(de),.I_new_result(1'b0),.I_valid(valid),
        .I_x(x),.I_y(y),.I_x0(12'd1000),.I_y0(12'd300),.I_x1(12'd1300),.I_y1(12'd500),
        .I_cx(12'd1150),.I_cy(12'd400),.I_state(2'd0),.I_dir_x(2'd0),.I_dir_y(2'd0),
        .I_level_x(2'd0),.I_level_y(2'd0),.I_error_x(13'sd0),.I_error_y(13'sd0),.I_area_percent(7'd0),
        .O_hit(hit),.O_color(color));
    task pixel(input integer px,py,input bit expect_hit,input [23:0] expect_color);
        x=px;y=py;#1;
        if(hit!==expect_hit || (expect_hit && color!==expect_color))
            $fatal(1,"Overlay at %0d,%0d hit=%b color=%h",px,py,hit,color);
    endtask
    integer px,py;
    initial begin
        for(py=24;py<184;py=py+1)
            for(px=24;px<440;px=px+1) pixel(px,py,0,0);
        pixel(960,540,1,24'hffffff); // Reference center.
        pixel(912,504,1,24'h00bfff); // Hysteresis outer boundary.
        pixel(1008,576,1,24'h00bfff);
        pixel(920,510,0,0);
        pixel(1000,300,0,0); // No stale target box after loss.
        valid=1;
        pixel(1000,300,1,24'h00ff80);
        pixel(1001,350,1,24'h00ff80);
        pixel(1002,350,0,0);
        pixel(1300,500,1,24'h00ff80);
        pixel(1100,450,0,0); // Box interior remains video.
        pixel(1150,400,1,24'hffff00);
        pixel(1158,400,1,24'hffff00);
        pixel(1159,400,0,0);
        pixel(100,100,0,0); // No former text/background even while locked.
        de=0;pixel(1000,300,0,0);pixel(960,540,0,0);
        de=1;enable=0;pixel(1000,300,0,0);pixel(960,540,0,0);
        $display("PASS red geometry OSD: former panel transparent, valid-only box, target/reference centers, dead zone, mode/DE gating");
        $finish;
    end
endmodule
