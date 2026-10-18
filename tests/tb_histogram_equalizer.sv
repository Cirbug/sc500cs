`timescale 1ns/1ps
module tb_histogram_equalizer;
    reg clk=0,apb=0;always #7 clk=~clk;always #10 apb=~apb;
    reg rst=0,sel=0,en=0,wr=0;reg[11:0] addr=0;reg[3:0] strobe=15;reg[31:0] wd=0;
    wire[31:0] rd;reg vs=0,hs=0,de=0;reg[23:0] rgb=0;
    wire ov,oh,od;wire[23:0] out;
    histogram_equalizer dut(rst,apb,sel,en,wr,addr,strobe,wd,rd,clk,vs,hs,de,rgb,ov,oh,od,out);
    task write_reg(input[11:0] a,input[31:0] v);
        begin
            @(negedge apb);sel=1;en=0;wr=1;addr=a;wd=v;
            @(negedge apb);en=1;
            @(negedge apb);sel=0;en=0;wr=0;
        end
    endtask
    task read_reg(input[11:0] a,output[31:0] v);
        begin
            @(negedge apb);sel=1;en=0;wr=0;addr=a;
            @(negedge apb);en=1;#1;v=rd;
            @(negedge apb);sel=0;en=0;
        end
    endtask
    integer curve=0;
    function[23:0] golden(input[23:0] p);
        integer y,t,d,r,g,b;
        begin
            y=(p[23:16]+2*p[15:8]+p[7:0])/4;
            t=curve==1?255-y:curve==2?128:y;d=t-y;
            r=p[23:16]+d;g=p[15:8]+d;b=p[7:0]+d;
            if(r<0)r=0;if(r>255)r=255;if(g<0)g=0;if(g>255)g=255;if(b<0)b=0;if(b>255)b=255;
            golden={8'(r),8'(g),8'(b)};
        end
    endfunction
    reg[23:0] p0=0,p1=0,p2=0;reg[2:0] vd=0,hd=0,dd=0;
    always @(posedge clk) if(rst) begin
        p2=p1;p1=p0;p0=golden(rgb);vd={vd[1:0],vs};hd={hd[1:0],hs};dd={dd[1:0],de};
        #1;
        if({ov,oh,od}!={vd[2],hd[2],dd[2]}) $fatal(1,"sync latency mismatch");
        if(od && out!==p2) $fatal(1,"pixel mismatch curve=%0d got=%h expected=%h",curve,out,p2);
    end
    task boundary;
        begin @(negedge clk);vs=1;de=0;repeat(3)@(negedge clk);vs=0;repeat(8)@(negedge clk);end
    endtask
    task frame(input integer w,input integer h,input integer pattern);
        integer x,y;reg[7:0] value;
        begin
            for(y=0;y<h;y=y+1) begin
                for(x=0;x<w;x=x+1) begin
                    @(negedge clk);de=1;hs=0;
                    value=pattern==0?64:pattern==1?x*2:255;rgb={value,value,value};
                end
                @(negedge clk);de=0;hs=1;repeat(4)@(negedge clk);hs=0;
            end
            repeat(10)@(negedge clk);
        end
    endtask
    task lut(input integer which);
        integer i;
        begin write_reg('h10,0);for(i=0;i<256;i=i+1)write_reg('h14,which==1?255-i:128);write_reg('h18,1);end
    endtask
    integer i;reg[31:0] v;
    initial begin
        repeat(5)@(negedge clk);rst=1;
        read_reg(0,v);if(v!==32'h48455131)$fatal(1,"ID");
        boundary();frame(128,24,1);
        $display("PASS HEQ1 bypass has exact RGB and three-cycle sync latency");
        write_reg(8,1);repeat(280)@(negedge clk);boundary();frame(128,24,0);boundary();
        repeat(8)@(negedge apb);read_reg(4,v);if((v&5)!=4)$fatal(1,"capture status %h",v);
        read_reg(8,v);if(v!=48)$fatal(1,"sample count %d",v);
        for(i=0;i<256;i=i+1)begin read_reg('h400+4*i,v);if(v!=(i==64?48:0))$fatal(1,"hist bin %0d %0d",i,v);end
        frame(128,24,1);boundary();read_reg('h500,v);if(v!=48)$fatal(1,"snapshot not held");
        write_reg(8,1);repeat(280)@(negedge clk);boundary();frame(128,24,1);boundary();
        repeat(8)@(negedge apb);
        for(i=0;i<256;i=i+1)begin read_reg('h400+4*i,v);if(v!=(i%16==0?3:0))$fatal(1,"new histogram not cleared %0d %0d",i,v);end
        $display("PASS HEQ1 same-bin accumulation, sampled ramp, snapshot ownership and next-capture clear");
        write_reg('h10,0);write_reg('h14,123);write_reg('h18,1);read_reg(4,v);
        if(!(v&16) || (v&2))$fatal(1,"partial LUT committed");
        lut(1);frame(128,24,1);read_reg(4,v);if(!(v&2))$fatal(1,"commit did not wait for VSYNC");
        write_reg('h1c,1);repeat(8)@(negedge clk);curve=1;boundary();frame(128,24,1);
        read_reg(4,v);if((v&42)!=40)$fatal(1,"map/enable ack %h",v);
        lut(2);frame(128,24,1);curve=2;boundary();frame(128,24,1);
        // Color clipping, full throughput, and blanking alignment.
        for(i=0;i<100;i=i+1)begin @(negedge clk);de=1;rgb=$random;end
        @(negedge clk);de=0;repeat(6)@(negedge clk);
        write_reg('h1c,0);frame(128,24,1);curve=0;boundary();frame(128,24,1);
        $display("PASS HEQ1 partial-write rejection, frame-atomic LUT swap/enable, RGB clipping and disable");
        write_reg(8,1);repeat(280)@(negedge clk);boundary();frame(1920,1080,2);boundary();
        repeat(8)@(negedge apb);read_reg(8,v);if(v!=32400)$fatal(1,"1080p count %d",v);
        read_reg('h7fc,v);if(v!=32400)$fatal(1,"1080p constant-bin overflow %d",v);
        $display("PASS HEQ1 full 1920x1080 frame: 32400 samples, no same-bin loss/overflow");
        $finish;
    end
    initial begin #100000000;$fatal(1,"timeout");end
endmodule
