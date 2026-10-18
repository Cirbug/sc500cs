`timescale 1ns/1ps
module tb_shape_filter;
    reg clk=0,rst=0,en=1,fs=0,nr=0,rv=0;
    reg [2:0] rt=0;reg [11:0] x0=400,y0=300,x1=900,y1=800;
    wire v;wire [2:0] k;wire [11:0] a,b,c,d;
    always #5 clk=~clk;
    shape_result_filter dut(clk,rst,en,fs,nr,rv,rt,x0,y0,x1,y1,v,k,a,b,c,d);
    task publish(input integer t);
        @(negedge clk);rt=t;rv=t!=0;nr=1;@(negedge clk);nr=0;
        repeat(2)@(negedge clk);fs=1;@(negedge clk);fs=0;
    endtask
    initial begin
        #2;rst=0;#20;rst=1;
        repeat(4)publish(1);if(v)$fatal(1,"early acquire");
        publish(1);if(!v || k!=1)$fatal(1,"acquire");
        publish(3);publish(1);publish(0);publish(1);
        if(!v || k!=1)$fatal(1,"one-frame flicker");
        repeat(7)publish(3);if(v && k!=1)$fatal(1,"early class switch");
        publish(3);if(!v || k!=3)$fatal(1,"switch confirmation");
        repeat(4)publish(0);if(v)$fatal(1,"persistent ambiguity frozen forever");
        repeat(5)publish(4);if(!v || k!=4)$fatal(1,"reacquire triangle");
        x0=1300;x1=1800;
        publish(1);if(v)$fatal(1,"old label attached to different target");
        repeat(4)publish(1);if(!v || k!=1 || a!=1300)$fatal(1,"new target acquire");
        repeat(7)begin @(negedge clk);fs=1;@(negedge clk);fs=0;end
        if(v)$fatal(1,"missing scanner watchdog");
        repeat(5)publish(1);if(!v)$fatal(1,"watchdog recovery");
        en=0;@(negedge clk);if(v || k)$fatal(1,"disable");
        $display("PASS shape filter: acquire, isolated errors, switch, ambiguity timeout, identity, scanner timeout, mode exit");$finish;
    end
endmodule
