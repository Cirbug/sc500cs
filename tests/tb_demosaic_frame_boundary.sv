`timescale 1ns/1ps
// Pixel reference is independent of the DUT's packed window implementation.
module tb_demosaic_frame_boundary;
    parameter W=64, H=8, FRAMES=6, GAPS=0, LINE_GAP=110;
    reg clk=0, rst_n=0, valid=0, sof=0, eol=0;
    reg [39:0] raw=0;
    wire ov, os, ol;
    wire [127:0] rgb;
    integer frame_id=0, received=0, errors=0, frame_base=0;
    integer ox, oy, oframe, expected, actual;
    bit baseline,checking=0;
    always #5 clk=~clk;
    demosaic #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) dut (
        .I_clk(clk),.I_rst_n(rst_n),.axi4s_video_tdata(raw),.axi4s_video_tdest(10'd0),
        .axi4s_video_tlast(eol),.axi4s_video_tvalid(valid),.axi4s_video_tuser(sof),
        .axi4s_video_tready(),.O_tlast(ol),.O_tuser(os),.O_tdata(rgb),
        .O_tvalid(ov),.O_tready(1'b1));
    function automatic integer component(input integer f,x,y,c);
        if(f==0) component=(c==0 ? 80 : c==1 ? 160 : 60);
        else if(f==1) component=(17*x+11*y+53*c)%220+8;
        else if(f==2) component=0;
        else component=c==f-3 ? 200 : 0;
    endfunction
    function automatic integer sample(input integer f,x,y);
        integer xx,yy,c;
        begin
            xx=x<0 ? -x : x>=W ? 2*W-2-x : x;
            yy=y<0 ? -y : y>=H ? 2*H-2-y : y;
            c=(yy%2==0) ? ((xx%2==0)?2:1) : ((xx%2==0)?1:0);
            sample=component(f,xx,yy,c);
        end
    endfunction
    function automatic integer reference(input integer f,x,y,c);
        integer own;
        begin
            own=(y%2==0) ? ((x%2==0)?2:1) : ((x%2==0)?1:0);
            if(c==own) reference=sample(f,x,y);
            else if(own!=1 && c!=1)
                reference=(sample(f,x-1,y-1)+sample(f,x+1,y-1)+sample(f,x-1,y+1)+sample(f,x+1,y+1))/4;
            else if(c==1)
                reference=(sample(f,x-1,y)+sample(f,x+1,y)+sample(f,x,y-1)+sample(f,x,y+1))/4;
            else if((y%2==0 && c==2)||(y%2==1 && c==0))
                reference=(sample(f,x-1,y)+sample(f,x+1,y))/2;
            else reference=(sample(f,x,y-1)+sample(f,x,y+1))/2;
        end
    endfunction
    always @(posedge clk) begin
        #1;
        if(rst_n && checking && ov) begin
            oframe=received/(W*H/4); oy=(received%(W*H/4))/(W/4); ox=(received%(W/4))*4;
            if(os !== (ox==0 && oy==0) || ol !== (ox==W-4)) begin
                if(!baseline) $fatal(1,"control mismatch f=%0d x=%0d y=%0d SOF=%b EOL=%b",oframe,ox,oy,os,ol);
                errors=errors+1;
            end
            for(integer p=0;p<4;p=p+1) for(integer c=0;c<3;c=c+1) begin
                expected=reference(oframe,ox+p,oy,c);
                actual=(rgb>>(p*32+(2-c)*8))&255;
                if($isunknown(rgb[p*32+:24]) || actual!=expected) begin
                    if(errors<8) $display("MISMATCH f=%0d x=%0d y=%0d c=%0d got=%0d expected=%0d",oframe,ox+p,oy,c,actual,expected);
                    errors=errors+1;
                end
            end
            received=received+1;
        end
    end
    task automatic idle(input integer n);
        begin
            @(negedge clk); valid=0;sof=0;eol=0;
            repeat(n) @(negedge clk);
        end
    endtask
    initial begin
        baseline=$test$plusargs("baseline");
        repeat(8) @(negedge clk);rst_n=1;
        if($test$plusargs("reset_partial")) begin
            // Abort a live partial frame with RAM contents left dirty.
            for(integer k=0;k<W/4*3;k=k+1) begin
                @(negedge clk);valid=1;sof=(k==0);eol=(k%(W/4)==W/4-1);raw={4{10'd800}};
            end
            @(negedge clk);valid=0;sof=0;eol=0;rst_n=0;
            repeat(5) @(negedge clk);rst_n=1;
        end
        checking=1;
        for(integer f=0;f<FRAMES;f=f+1) begin
            for(integer y=0;y<H;y=y+1) begin
                for(integer x=0;x<W;x=x+4) begin
                    @(negedge clk);valid=1;sof=(x==0 && y==0);eol=(x==W-4);
                    for(integer p=0;p<4;p=p+1) raw[p*10+:10]=sample(f,x+p,y)*4;
                    if(GAPS && x<W-4) idle((x/4)%3);
                end
                if(LINE_GAP>0) idle(LINE_GAP);
            end
            idle(W/4+150);
            if(received!=(f+1)*W*H/4) $fatal(1,"frame count f=%0d got=%0d expected=%0d",f,received,(f+1)*W*H/4);
        end
        if(baseline) begin
            if(errors==0) $fatal(1,"baseline did not reproduce pixel defect");
            $display("PASS baseline reproduced %0d component errors; W=%0d H=%0d frames=%0d",errors,W,H,FRAMES);
        end else begin
            if(errors) $fatal(1,"pixel reference failed: %0d component errors",errors);
            $display("PASS demosaic all pixels, borders, SOF/EOL: W=%0d H=%0d frames=%0d gaps=%0d",W,H,FRAMES,GAPS);
        end
        $finish;
    end
    initial begin #200000000;$fatal(1,"timeout");end
endmodule
