`timescale 1ns/1ps
module tb_red_target_tracker #(parameter REPORT_AREA_PERCENT=1);
    reg clk=0,rst=0,enable=1,reacquire=0,user=0,de=0;
    reg [23:0] data=0;
    always #5 clk=~clk;
    wire result,valid;wire [1:0] state,dx,dy,lx,ly;
    wire [11:0] x0,y0,x1,y1,cx,cy;wire signed [12:0] ex,ey;wire [6:0] area;
    red_target_tracker #(.IMG_WIDTH(160),.IMG_HEIGHT(96),.DEAD_X_ENTER(8),.DEAD_X_EXIT(12),
        .DEAD_Y_ENTER(8),.DEAD_Y_EXIT(12),.LEVEL_X_MEDIUM(20),.LEVEL_X_LARGE(40),
        .LEVEL_Y_MEDIUM(16),.LEVEL_Y_LARGE(32),.REPORT_AREA_PERCENT(REPORT_AREA_PERCENT)) dut
          (.I_clk(clk),.I_rst_n(rst),.I_enable(enable),.I_reacquire(reacquire),
           .I_user(user),.I_de(de),.I_data(data),
           .O_new_result(result),.O_valid(valid),.O_state(state),
           .O_x0(x0),.O_y0(y0),.O_x1(x1),.O_y1(y1),.O_cx(cx),.O_cy(cy),
           .O_error_x(ex),.O_error_y(ey),.O_dir_x(dx),.O_dir_y(dy),
           .O_level_x(lx),.O_level_y(ly),.O_area_percent(area));
    integer results=0;
    always @(posedge clk) if(result) results=results+1;
    // kind: red left; same-size blue; red right + small left distractor; empty.
    task frame(input integer kind);
        integer x,y;
        @(negedge clk);user=1;de=0;
        @(negedge clk);user=0;
        for(y=0;y<96;y=y+1) begin
            for(x=0;x<160;x=x+1)begin
                de=1;data=24'h202020;
                if((kind==1 || kind==2) && x>=16 && x<64 && y>=16 && y<64)
                    data=kind==1 ? 24'hd02020 : 24'h2020d0;
                if(kind==3 && x>=96 && x<144 && y>=32 && y<80)data=24'hd02020;
                if(kind==3 && x<16 && y<16)data=24'hd02020;
                @(negedge clk);
            end
            de=0;repeat(2)@(negedge clk);
        end
        repeat(5000)@(negedge clk);
    endtask
    initial begin
        #2;rst=0;#20;rst=1;
        frame(1);frame(1);frame(1);
        if(valid)$fatal(1,"locked before three complete results");
        frame(1);
        if(!valid || state!=1 || x0!=16 || x1!=63 || y0!=16 || y1!=63 || cx!=39 || cy!=39 || ex!=-41 || dx!=1 || lx!=3 || dy!=0 || area!=(REPORT_AREA_PERCENT ? 15 : 0))
            $fatal(1,"red lock/box/command wrong: valid=%b cx=%d ex=%d area=%d",valid,cx,ex,area);
        frame(2);frame(2);
        if(valid || state!=2 || dx || dy || lx || ly)$fatal(1,"non-red/lost must hold immediately");
        repeat(5)frame(0);
        if(valid || state!=0)$fatal(1,"loss must return to search");
        repeat(4)frame(3);
        if(!valid || cx!=119 || x0!=96 || x1!=143 || dx!=2)$fatal(1,"component selection merged distant distractor");
        @(negedge clk);reacquire=1;@(negedge clk);reacquire=0;
        if(valid || dx || state)$fatal(1,"reacquire");
        repeat(4)frame(1);
        if(!valid || cx!=39)$fatal(1,"reacquire failed");
        @(negedge clk);enable=0;@(negedge clk);
        if(valid || dx || dy)$fatal(1,"mode exit");
        $display("PASS red detector: confirmation, component box/area, directions, colour rejection, loss, distractor, reacquire, disable (%0d results; percentage=%0d)",results,REPORT_AREA_PERCENT);$finish;
    end
    initial begin #10000000;$fatal(1,"timeout");end
endmodule
