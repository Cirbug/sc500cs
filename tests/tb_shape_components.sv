`timescale 1ns/1ps
// Same 120x68 sample geometry as 1080p; shorter pixel spacing accelerates cases.
module tb_shape_components #(parameter PIXEL_SHIFT=1);
    localparam W=120*(1<<PIXEL_SHIFT),H=(PIXEL_SHIFT==4)?1080:68*(1<<PIXEL_SHIFT);
    reg clk=0,rst=0,enable=1,reacquire=0,user=0,de=0,shape_mode=1;
    reg [23:0] data=0;
    always #5 clk=~clk;
    wire result,valid;wire [2:0] kind;wire [11:0] x0,y0,x1,y1;
    wire [1:0] dx,dy,lx,ly;
    red_shape_tracker #(.IMG_WIDTH(W),.IMG_HEIGHT(H),.SAMPLE_SHIFT(PIXEL_SHIFT),.REPORT_AREA_PERCENT(0)) dut(
        .I_clk(clk),.I_rst_n(rst),.I_enable(enable),.I_reacquire(reacquire),.I_user(user),.I_de(de),.I_data(data),
        .I_shape_mode(shape_mode),.O_shape_type(kind),.O_new_result(result),.O_valid(valid),
        .O_x0(x0),.O_y0(y0),.O_x1(x1),.O_y1(y1),.O_state(),.O_cx(),.O_cy(),.O_error_x(),.O_error_y(),
        .O_dir_x(dx),.O_dir_y(dy),.O_level_x(lx),.O_level_y(ly),.O_area_percent());
    reg [23:0] pixels[0:8159];
    string path;
    integer expected,scenario,watchdog,components,raws,expected_x0,expected_x1,check_box;
    task frame;
        integer x,y;
        @(negedge clk);user=1;de=0;
        @(negedge clk);user=0;
        for(y=0;y<H;y=y+1)begin
            for(x=0;x<W;x=x+1)begin
                de=1;data=pixels[(y>>PIXEL_SHIFT)*120+(x>>PIXEL_SHIFT)];@(negedge clk);
            end
            de=0;repeat(2)@(negedge clk);
        end
    endtask
    always @(posedge clk) if(rst && shape_mode && (dx || dy || lx || ly))$fatal(1,"shape mode generated servo command");
    always @(posedge clk) if(rst && dut.state==11) components=components+1;
    initial begin
        components=0;raws=0;
        if(!$value$plusargs("PIXELS=%s",path))$fatal(1,"PIXELS missing");
        if(!$value$plusargs("EXPECTED=%d",expected))$fatal(1,"EXPECTED missing");
        check_box=$value$plusargs("X0=%d",expected_x0);
        if(check_box && !$value$plusargs("X1=%d",expected_x1))$fatal(1,"X1 missing");
        $readmemh(path,pixels);
        #2;rst=0;#20;rst=1;
        frame();
        @(negedge clk);user=1;@(negedge clk);user=0;
        watchdog=0;
        while(!result && watchdog<1500000)begin @(negedge clk);watchdog=watchdog+1;end
        if(!result)$fatal(1,"component scan timeout state=%0d",dut.state);
        if(valid !== (expected!=0) || (valid && kind!=expected))
            $fatal(1,"shape mismatch expected=%0d valid=%b kind=%0d box=%0d,%0d,%0d,%0d",expected,valid,kind,x0,y0,x1,y1);
        if(kind==2 || kind==5)$fatal(1,"removed class published");
        if(check_box && (x0!=expected_x0 || x1!=expected_x1))$fatal(1,"adjacent unlike colours merged");
        $display("PASS shape components expected=%0d kind=%0d components=%0d scan_cycles=%0d box=%0d,%0d,%0d,%0d",expected,kind,components,watchdog,x0,y0,x1,y1);
        // A direct mode change must flush both old mask ownership and result.
        shape_mode=0;@(negedge clk);
        if(valid || kind || dut.frame_started || dut.stack_size)$fatal(1,"mode transition kept stale shape");
        enable=0;@(negedge clk);
        if(valid || dx || dy)$fatal(1,"disable failed");
        $finish;
    end
endmodule
