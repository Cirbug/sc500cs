`timescale 1ns/1ps
// Native geometry catches padded mask rows, clipped edge boxes and ERAM stack
// capacity. CONFIRM_FRAMES=1 accelerates this test; 3-frame locking is tested
// separately in tb_red_target_tracker. All other detector defaults are used.
module tb_red_tracker_1080p;
    reg clk=0,rst=0,enable=1,reacquire=0,user=0,de=0;reg [23:0] data=0;
    always #5 clk=~clk;
    wire result,valid;wire [1:0] state,dx,dy,lx,ly;
    wire [11:0] x0,y0,x1,y1,cx,cy;wire signed [12:0] ex,ey;wire [6:0] area;
    red_target_tracker #(.CONFIRM_FRAMES(1)) dut
        (clk,rst,enable,reacquire,user,de,data,result,valid,state,x0,y0,x1,y1,cx,cy,ex,ey,dx,dy,lx,ly,area);
    integer result_count=0;
    always @(posedge clk) if(result) result_count=result_count+1;
    task frame(input integer kind);
        integer x,y;
        @(negedge clk);user=1;de=0;
        @(negedge clk);user=0;
        for(y=0;y<1080;y=y+1)begin
            for(x=0;x<1920;x=x+1)begin
                de=1;data=24'h202020;
                if(kind==1 && x>=1440 && y>=800)data=24'he02020;
                if(kind==2)data=24'he02020;
                if(kind==3 && ((x/16+y/16)%2==0))data=24'he02020;
                @(negedge clk);
            end
            de=0;repeat(4)@(negedge clk);
        end
        repeat(200000)@(negedge clk);
    endtask
    initial begin
        #2;rst=0;#20;rst=1;
        frame(1);frame(1);
        if(!valid || x0!=1440 || y0!=800 || x1!=1919 || y1!=1079 || cx!=1679 || cy!=939 || ex!=719 || ey!=399 || dx!=2 || dy!=2 || lx!=3 || ly!=3 || area!=6)
            $fatal(1,"1080p edge geometry or default thresholds");
        @(negedge clk);reacquire=1;@(negedge clk);reacquire=0;
        frame(2);frame(2);
        if(!valid || area!=100 || x0 || y0 || x1!=1919 || y1!=1079 || dx || dy)
            $fatal(1,"full red mask / stack capacity / center dead zone");
        frame(3);frame(3);
        if(valid || dx || dy || area)$fatal(1,"isolated red noise must not merge into a target");
        $display("PASS native 1920x1080 tracker: clipped bottom edge, full mask flood fill, 4080 isolated components (%0d results)",result_count);$finish;
    end
    initial begin #200000000;$fatal(1,"timeout");end
endmodule
