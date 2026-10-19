`timescale 1ns/1ps
module tb_menu_soften;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,de=0,vs=0;reg [11:0] x=0,y=900;
    reg [23:0] pixel=0;wire [23:0] out_pixel;wire out_de,out_vs;
    mcu_menu_table dut(.clk(clk),.apb_clk(clk),.rst_n(rst),.sel(1'b0),.enable(1'b0),.write(1'b0),
        .addr(8'd0),.strobe(4'd0),.wdata(32'd0),.vs(vs),.hs(1'b0),.de(de),.x(x),.y(y),.pixel(pixel),
        .cn_id(7'd0),.cn_row(5'd0),.cn_col(5'd0),.cn_active(1'b0),.cn_color(24'd0),
        .out_pixel(out_pixel),.out_de(out_de),.out_vs(out_vs));
    integer hr=0,hg=0,hb=0;reg active=0;reg [23:0] want;
    integer k;
    task sample(input [23:0] rgb,input integer xpos,input bit valid_pixel,input bit frame_start);
        @(negedge clk);pixel=rgb;x=xpos;de=valid_pixel;vs=frame_start;
        if(!active || !de || vs || x==0)begin
            hr=4*rgb[23:16];hg=4*rgb[15:8];hb=4*rgb[7:0];
        end else begin
            hr=hr-(hr/4)+rgb[23:16];hg=hg-(hg/4)+rgb[15:8];hb=hb-(hb/4)+rgb[7:0];
        end
        active=de && !vs;
        want=rgb;
        if(x>=24 && x<492) begin
            want[23:16]=(hr/4)/2+8;
            want[15:8]=(hg/4)/2+12;
            want[7:0]=(hb/4)/2+16;
        end
        if(x==24 || x==25 || x==490 || x==491)want=24'h304652;
        @(posedge clk);#1;
        if(out_de!==de || out_vs!==vs)$fatal(1,"video sync changed");
        if(out_pixel!==want)$fatal(1,"x=%0d got=%h expected=%h",x,out_pixel,want);
    endtask
    initial begin
        #12;rst=1;
        // Isolate the compositor from APB table publication (covered by panel/bus tests).
        force dut.valid=1;
        force dut.desc=32'h00800000;
        for(k=0;k<520;k++)sample(k[0]?24'hff0080:24'h00ff20,k,1,0);
        sample(24'hffffff,500,0,0);
        sample(24'h000000,40,1,0); // New line must not inherit the previous line.
        sample(24'hffffff,41,1,0);
        sample(24'h010203,0,1,1); // VSYNC also clears the history.
        sample(24'h808080,40,1,0);
        // Foreground border remains crisp.
        @(negedge clk);x=24;pixel=24'hffffff;@(posedge clk);#1;
        if(out_pixel!==24'h304652)$fatal(1,"border softened");
        // Invalid/hidden table must remain a pixel-exact passthrough.
        force dut.desc=32'd0;
        @(negedge clk);x=50;pixel=24'h123456;@(posedge clk);#1;
        if(out_pixel!==24'h123456)$fatal(1,"hidden menu modifies camera");
        $display("PASS horizontal softening: RGB reference, line/VS reset, exact outside pixels, sync, crisp border, hidden menu");
        $finish;
    end
endmodule
