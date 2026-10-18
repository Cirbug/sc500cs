`timescale 1ns/1ps
module tb_shape_sequence;
    reg clk=0,rst=0,en=1,user=0,de=0;reg [23:0] data=0;
    always #5 clk=~clk;
    wire nr,rv,v;wire [2:0] rt,k;wire [11:0] x0,y0,x1,y1,a,b,c,d;
    red_shape_tracker #(.IMG_WIDTH(240),.IMG_HEIGHT(136),.SAMPLE_SHIFT(1),.REPORT_AREA_PERCENT(0)) scan(
        .I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_reacquire(1'b0),.I_user(user),.I_de(de),.I_data(data),
        .I_shape_mode(1'b1),.O_shape_type(rt),.O_new_result(nr),.O_valid(rv),.O_x0(x0),.O_y0(y0),.O_x1(x1),.O_y1(y1),
        .O_state(),.O_cx(),.O_cy(),.O_error_x(),.O_error_y(),.O_dir_x(),.O_dir_y(),.O_level_x(),.O_level_y(),.O_area_percent());
    shape_result_filter filter(clk,rst,en,user,nr,rv,rt,x0,y0,x1,y1,v,k,a,b,c,d);
    integer index,xx,yy;
    reg fs_d;
    reg [51:0] display_d;
    always @(posedge clk)begin
        fs_d<=user;display_d<={v,k,a,b,c,d};
        if(rst && en && !fs_d && {v,k,a,b,c,d}!==display_d)$fatal(1,"public result changed within a frame");
    end
    task frame(input integer primary,input integer distractor,input integer jitter);
        integer x,y,sx,sy;
        @(negedge clk);user=1;de=0;@(negedge clk);user=0;
        for(y=0;y<136;y=y+1)begin
            for(x=0;x<240;x=x+1)begin
                sx=x/2;sy=y/2;de=1;data=24'h909090;
                if(primary && sx>=30+jitter && sx<=54+jitter && sy>=20 && sy<=44)data=24'h202020;
                if(distractor && (sx-95)*(sx-95)+(sy-34)*(sy-34)<=17*17)data=24'hd02020;
                @(negedge clk);
            end
            de=0;repeat(2)@(negedge clk);
        end
        // Scan and next capture overlap during active video; bounded blanking
        // lets this deliberately accelerated test retain a complete mask.
        repeat(300000)@(negedge clk);
    endtask
    initial begin
        #2;rst=0;#20;rst=1;
        for(index=0;index<8;index=index+1)frame(1,0,index%2);
        if(!v || k!=1 || a>80)$fatal(1,"initial rectangle not acquired");
        for(index=0;index<8;index=index+1)begin
            frame(1,1,index%2);
            if(!v || k!=1 || a>80)$fatal(1,"larger unrelated circle stole locked rectangle");
        end
        for(index=0;index<15;index=index+1)frame(0,1,0);
        if(!v || k!=3 || a<130)$fatal(1,"target replacement never reacquired circle");
        repeat(7)frame(0,0,0);
        if(v)$fatal(1,"absent target remained visible");
        $display("PASS shape sequence: concurrent capture/scan, frame-atomic OSD, moving target, larger distractor, removal and reacquisition");$finish;
    end
endmodule
