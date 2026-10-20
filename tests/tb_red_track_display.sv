`timescale 1ns/1ps
module tb_red_track_display;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,enable=1,reacquire=0,frame_start=0,new_result=0,valid=1;
    reg [11:0] x0=100,y0=100,x1=400,y1=400,cx=960,cy=540;
    wire out_valid,xneg,yneg;
    wire [11:0] ox0,oy0,ox1,oy1,ocx,ocy;
    wire [15:0] xb,yb;
    red_track_display dut(.clk(clk),.rst_n(rst),.enable(enable),.reacquire(reacquire),
        .frame_start(frame_start),.new_result(new_result),.valid(valid),
        .x0(x0),.y0(y0),.x1(x1),.y1(y1),.cx(cx),.cy(cy),.out_valid(out_valid),
        .out_x0(ox0),.out_y0(oy0),.out_x1(ox1),.out_y1(oy1),.out_cx(ocx),.out_cy(ocy),
        .x_negative(xneg),.y_negative(yneg),.x_bcd(xb),.y_bcd(yb));
    task tick; @(posedge clk);#1;@(negedge clk);endtask
    task submit(input integer px,py);
        cx=px;cy=py;new_result=1;tick;new_result=0;
    endtask
    task commit;
        frame_start=1;tick;frame_start=0;
    endtask
    function integer decimal(input [15:0] bcd);
        if(bcd[15:12]>9 || bcd[11:8]>9 || bcd[7:4]>9 || bcd[3:0]>9)
            $fatal(1,"Invalid BCD %h",bcd);
        decimal=bcd[15:12]*1000+bcd[11:8]*100+bcd[7:4]*10+bcd[3:0];
    endfunction
    task check_center(input integer px,py);
        integer ex,ey;
        ex=px-960;ey=540-py;
        if(!out_valid || ocx!=px || ocy!=py ||
           {ox0,oy0,ox1,oy1}!={x0,y0,x1,y1} ||
           xneg!=(ex<0) || yneg!=(ey<0) ||
           decimal(xb)!=(ex<0?-ex:ex) || decimal(yb)!=(ey<0?-ey:ey))
            $fatal(1,"Center=%0d,%0d box/cross/text mismatch x=%b:%h y=%b:%h",px,py,xneg,xb,yneg,yb);
    endtask
    integer i,old_x,old_y;
    initial begin
        repeat(3) tick;rst=1;tick;
        submit(960,540);repeat(12) tick;
        if(out_valid) $fatal(1,"Published without frame start");
        commit;check_center(960,540);
        // Every possible horizontal and vertical screen coordinate.
        for(i=0;i<3000;i=i+1) begin
            old_x=ocx;old_y=ocy;
            if(i<1920) submit(i,(i*37)%1080);
            else submit((i*13)%1920,i-1920);
            // A frame starting during conversion must retain the complete old sample.
            commit;repeat(11) tick;
            if(ocx!=old_x || ocy!=old_y) $fatal(1,"Changed during active frame/conversion");
            commit;check_center(cx,cy);
        end
        // Newest complete result supersedes an interrupted conversion.
        submit(100,200);repeat(4) tick;submit(1919,1079);repeat(12) tick;
        commit;check_center(1919,1079);
        // Loss removes the whole annotation at the next boundary.
        valid=0;submit(0,0);
        if(!out_valid) $fatal(1,"Loss tore the active frame");
        commit;if(out_valid) $fatal(1,"Stale target after loss");
        valid=1;submit(960,540);repeat(12) tick;commit;check_center(960,540);
        // Simultaneous frame/result consumes the previous ready sample atomically.
        submit(1000,300);repeat(12) tick;
        frame_start=1;submit(900,700);frame_start=0;check_center(1000,300);
        repeat(12) tick;commit;check_center(900,700);
        reacquire=1;tick;reacquire=0;commit;
        if(out_valid) $fatal(1,"Reacquire retained target");
        submit(960,540);enable=0;tick;enable=1;repeat(16) tick;commit;
        if(out_valid) $fatal(1,"Disabled conversion was published");
        $display("PASS red display: 3000 centers, signs/zero/BCD, coherent box/cross, busy replacement, frame races, loss, reacquire, mode exit");
        $finish;
    end
endmodule
