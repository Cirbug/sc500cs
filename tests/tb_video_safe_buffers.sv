`timescale 1ns/1ps
module tb_video_safe_buffers;
    localparam WORDS=720,STRIDE=8192;
    reg c=0,d=0,p=0,rst_n=0,fs=0,cv=0,done=0,bad=0,vs=0,rd=0,block_writer=0;
    always #5.5 c=~c;always #4 d=~d;always #7 p=~p;
    reg [127:0] cd=0;
    wire wb,rb,we,re,published,reader_valid;
    wire [1:0] rp,reader_bank;
    wire [24:0] wa,ra;
    wire [127:0] wd;
    wire [23:0] pixel;
    wire [31:0] counts,cdiag,ddiag;
    reg ready=1,stall_ddr=0;
    video_in #(.FRAME_WORDS(WORDS),.STRIDE(STRIDE)) vi(
        .I_rst_n(rst_n),.I_camera_clk(c),.I_camera_frame_start(fs),.I_camera_valid(cv),
        .I_camera_data(cd),.I_mipi_rx_error(bad),.I_camera_stream_error(1'b0),.I_camera_frame_done(done),.I_ddr_clk(d),
        .I_display_pause(1'b0),.I_video_out_rd_busy(rb|block_writer),.I_reader_bank(reader_bank),
        .I_reader_valid(reader_valid),.O_video_in_wr_busy(wb),.O_video_out_rp(rp),
        .O_video_out_valid(published),.O_ddr_user_wr_en(we),.O_ddr_user_addr(wa),
        .O_ddr_user_wr_data(wd),.I_ddr_user_ready(ready),.O_frame_counts(counts),.O_capture_diag(cdiag));
    reg hold_replies=0;
    integer cycle=0,writes=0,displayed=0,k;
    integer produced=0,consumed=0;
    reg [31:0] due[0:4095];
    reg [127:0] reply_data[0:4095],mem[0:3071];
    wire response=produced!=consumed && cycle>=due[consumed%4096] && !hold_replies;
    video_out #(.FRAME_READ_WORDS(WORDS),.STRIDE(STRIDE)) vo(
        .I_rst_n(rst_n),.I_ddr_clk(d),.O_video_out_rd_busy(rb),.I_video_in_wr_busy(wb),
        .I_video_out_rp(rp),.I_video_out_valid(published),.O_reader_bank(reader_bank),
        .O_reader_valid(reader_valid),.O_display_diag(ddiag),.O_ddr_user_rd_en(re),
        .O_ddr_user_addr(ra),.I_ddr_user_ready(ready),.I_ddr_user_rd_valid(response),
        .I_ddr_user_rd_data(reply_data[consumed%4096]),.I_dsi_clk(p),.I_video_vsync(vs),
        .I_video_rd_en(rd),.O_vdieo_data(pixel));
    always @(posedge d) begin
        if(!rst_n) begin produced<=0;consumed<=0;cycle<=0;end
        else begin
            cycle<=cycle+1;ready<=!stall_ddr && cycle%257>15;
            if(we && re) $fatal(1,"shared DDR bus collision");
            if(we) begin
                if(reader_valid && wa/STRIDE==reader_bank) $fatal(1,"write overlaps active display");
                if(published && wa/STRIDE==rp) $fatal(1,"write overlaps published frame");
                if(wa/8>=3072) $fatal(1,"write outside live banks");
                mem[wa/8]<=wd;writes=writes+1;
            end
            if(response) consumed<=consumed+1;
            if(re) begin
                if(produced-consumed>=4096) $fatal(1,"test response queue overflow");
                reply_data[produced%4096]<=mem[ra/8];due[produced%4096]<=cycle+64;
                produced<=produced+1;
            end
        end
    end
    reg [1:0] last_rp=0;
    reg [15:0] previous_good=0;
    integer j;
    always @(negedge d) if(rst_n && counts[15:0]!=previous_good) begin
        previous_good=counts[15:0];last_rp=rp;
        for(j=0;j<WORDS;j=j+1) begin
            if(mem[rp*1024+j]!==mem[rp*1024]) $fatal(1,"published mixed/partial frame word=%0d",j);
            if(mem[rp*1024+j][7:0]==3 || mem[rp*1024+j][7:0]==5 || mem[rp*1024+j][7:0]==7 ||
               mem[rp*1024+j][7:0]==11 || mem[rp*1024+j][7:0]==13 || mem[rp*1024+j][7:0]==14)
                $fatal(1,"bad input frame was published");
        end
    end
    // Same unpacking timing as HDMI: sample two clocks after each read.
    reg [1:0] rd_pipe=0;
    reg [23:0] first_pixel;
    reg in_display=0;
    always @(posedge p) begin
        rd_pipe<={rd_pipe[0],rd};
        if(vs) in_display=0;
        #1;
        if(rst_n && rd_pipe[1] && pixel!=0) begin
            if(!in_display) begin first_pixel=pixel;in_display=1;displayed=displayed+1;end
            if(pixel!==first_pixel) $fatal(1,"visible frame mixes two source frames");
        end
    end
    task capture(input integer id,input integer n,input bit rx_bad,input bit send_eof=1);
        begin
            @(negedge c);fs=1;@(negedge c);fs=0;
            repeat(100) @(negedge c);
            for(integer w=0;w<n;w=w+1) begin
                cd={16{8'(id)}};cv=1;@(negedge c);cv=0;
                repeat(3) @(negedge c);
            end
            repeat(80) @(negedge c);bad=rx_bad;done=send_eof;@(negedge c);done=0;bad=0;
            block_writer=0;
            repeat(3200+id*13) @(negedge c);
        end
    endtask
    initial begin
        repeat(20) @(negedge c);rst_n=1;repeat(30) @(negedge c);
        capture(1,WORDS,0);capture(2,WORDS,0);
        capture(3,WORDS-1,0);capture(4,WORDS,0);
        capture(5,WORDS,1);capture(6,WORDS,0);
        block_writer=1;capture(7,WORDS,0);capture(8,WORDS,0);
        capture(9,WORDS,0);capture(10,WORDS,0);
        repeat(3000) @(negedge c);
        if(counts[15:0]!=7 || counts[31:16]!=3) $fatal(1,"frame counts=%h",counts);
        if(!cdiag[8] || displayed<3) $fatal(1,"overflow/display coverage missing");
        if(ddiag[1]) $fatal(1,"DDR reply accounting error");
        capture(11,WORDS+1,0);capture(12,WORDS,0);
        capture(13,WORDS,0,0); // Deliberately omit EOF.
        capture(14,WORDS,0);   // New SOF rejects 13; frame 14 must be skipped.
        capture(15,WORDS,0);   // Normal operation resumes after acknowledgement.
        if(counts[15:0]!=9 || counts[31:16]!=5) $fatal(1,"EOF/oversize counts=%h",counts);
        if(!cdiag[9] || !cdiag[11]) $fatal(1,"oversize/missing-EOF flags absent");
        // No new capture: force a whole refresh to run out, then recover.
        wait(vs);stall_ddr=1;repeat(11000) @(negedge p);
        if(ddiag[31:16]==0) $fatal(1,"display underflow was not counted");
        stall_ddr=0;repeat(16000) @(negedge p);
        if(vo.pixel_bad || ddiag[1]) $fatal(1,"display failed to recover next frame");
        // Replies cross several HDMI frame boundaries: keep the old bank
        // reserved and do not mix old replies into the new display FIFO.
        hold_replies=1;wait(vo.pending!=0);
        repeat(15000) @(negedge p);
        if(vo.phase!=0 || vo.pending==0) $fatal(1,"old replies not fenced at frame restart");
        hold_replies=0;repeat(16000) @(negedge p);
        if(vo.pixel_bad || ddiag[1]) $fatal(1,"late-reply recovery failed");
        $display("PASS actual async FIFOs: 9 complete frames, 5 rejected, missing-EOF successor skipped; no bank/bus collisions; coherent pixels; underflow and multi-frame late-reply recovery");
        $finish;
    end
    initial begin
        wait(rst_n);repeat(900) @(negedge p);
        forever begin
            vs=1;repeat(5) @(negedge p);vs=0;
            repeat(450) @(negedge p);
            repeat(2) begin rd=1;repeat(1920) @(negedge p);rd=0;repeat(100) @(negedge p);end
            repeat(400) @(negedge p);
        end
    end
    initial begin #3000000;$fatal(1,"timeout");end
endmodule
