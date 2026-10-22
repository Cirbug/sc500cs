`timescale 1ns/1ps
`include "video_integrity.v"
// Actual CSI decoder, RAW unpacker, ISP and capture writer. PHY and DDR
// electrical behavior are not modeled. Line RAMs have one-clock latency.
module tb_video_full_pipeline;
    reg clk=0,ddr=0,rst_n=0,hs=0,matcherr=0;
    reg [15:0] data=0;
    always #5 clk=~clk;
    always #4 ddr=~ddr;
    wire fs,fe,cv,rs,re,rv,av,af,al,pv,pf,done,bad,published,we;
    wire packet_end,packet_error,capture_error;
    wire [31:0] raw;
    wire [39:0] unpacked,axis_data;
    wire [127:0] packed_data,wd;
    wire [24:0] wa;
    wire [63:0] rxdiag;
    wire [31:0] counts,cdiag;
    csi_unpacket_2lane decoder(.I_clk(clk),.I_rst_n(rst_n),.I_hs_valid(hs),.I_hs_data(data),
        .O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(cv),.O_csi_hs(),.O_csi_data(raw),
        .O_csi_line_end(packet_end),.O_csi_packet_error(packet_error));
    raw10_unpacket_2lane unpacker(.I_clk(clk),.I_rst_n(rst_n),.I_csi_frame_start(fs),
        .I_csi_frame_end(fe),.I_csi_valid(cv),.I_csi_data(raw),
        .O_raw10_frame_start(rs),.O_raw10_frame_end(re),.O_raw10_valid(rv),.O_raw10_data(unpacked));
    uial2axis #(.IMG_WIDTH(2592),.IMG_HEIGHT(1944),.INPUT_DATA_WIDTH(40)) axis_adapter(
        .I_native_clk(clk),.I_rst_n(rst_n),.I_data(unpacked),.I_data_valid(rv),
        .I_data_start(rs),.I_data_end(re),.axis_tvalid(av),.axis_tdata(axis_data),
        .axis_tuser(af),.axis_tlast(al));
    isp_top isp(.axi4s_video_aclk(clk),.I_rst_n(rst_n),.I_tlast(al),.I_tuser(af),
        .I_tdata(axis_data),.I_tvalid(av),.I_tdest(10'd0),.O_tready(1'b1),
        .O_tdata(packed_data),.O_tuser(pf),.O_tvalid(pv),
        .I_awb_bypass(1'b0),.I_blc_off(8'd12),.I_gamma_en(1'b0),.I_gamma_sel(4'd4),.I_bright(2'd1),
        .I_core_sel(3'd0),.I_awb_gate_en(1'b1),.I_awb_gate_th(8'd48),
        .I_awb_smooth_en(1'b1),.I_sat_off(1'b0),.I_sat_sel(2'd1),.I_denoise(2'd0));
    video_rx_integrity check_rx(.clk(clk),.rst_n(rst_n),.line_end(packet_end),
        .packet_error(packet_error),.frame_start(fs),
        .frame_end(fe),.word_valid(cv),.lane_error(1'b0),.match_error(matcherr),
        .capture_error(capture_error),.frame_done(done),.frame_bad(bad),.diagnostics(rxdiag));
    video_in #(.REQUIRE_RAW_FRAME(1'b0)) vi(.I_rst_n(rst_n),.I_camera_clk(clk),.I_camera_frame_start(pf),
        .I_camera_valid(pv),.I_camera_data(packed_data),.I_mipi_rx_error(bad),
        .I_camera_stream_error(capture_error),
        .I_camera_frame_done(done),.I_ddr_clk(ddr),.I_display_pause(1'b0),
        .I_video_out_rd_busy(1'b0),.I_reader_bank(2'd0),.I_reader_valid(1'b0),
        .O_video_out_valid(published),.O_ddr_user_wr_en(we),.O_ddr_user_addr(wa),
        .O_ddr_user_wr_data(wd),.I_ddr_user_ready(1'b1),.O_frame_counts(counts),.O_capture_diag(cdiag));
    integer nraw=0,naxis=0,nrgb=0,npacked=0,sof=0,writes=0,nonzero_words=0;
    always @(posedge clk) if(rst_n) begin
        if(cv) nraw=nraw+1;
        if(av) naxis=naxis+1;
        if(isp.m_aixs_tvalid) nrgb=nrgb+1;
        if(pv) npacked=npacked+1;
        if(pf) begin sof=sof+1;if(pv) $fatal(1,"packed SOF overlaps payload");end
        if(done) $display("EOF raw=%0d axis=%0d demosaic=%0d packed=%0d SOF=%0d RX=%h",nraw,naxis,nrgb,npacked,sof,rxdiag);
    end
    always @(posedge ddr) if(rst_n && we) begin
        writes=writes+1;
        if($isunknown(wd)) $fatal(1,"uninitialized ISP pixels reached DDR");
        if(wd!=0) nonzero_words=nonzero_words+1;
    end
    `include "csi_header_test_functions.vh"
    task short_packet(input [7:0] dtype,input bit close_hs=1);
        begin
            @(negedge clk);hs=1;data={dtype,8'h00};
            @(negedge clk);data={8'h00,test_header_ecc({16'h0000,dtype})};
            if(close_hs) begin
                // PHY valid can stay high into trail: reproduce board regression.
                repeat(24) begin @(negedge clk);data=0;end
                @(negedge clk);hs=0;repeat(80) @(negedge clk);
            end
        end
    endtask
    task raw_line(input integer row,input bit close_hs=1);
        begin
            @(negedge clk);hs=1;data={8'h2b,8'ha8}; // 3240 bytes
            @(negedge clk);data=16'h0c3b;
            for(integer n=0;n<1620;n=n+1) begin @(negedge clk);data=16'h8080;end
            @(negedge clk);data=0; // payload CRC, not validated here
            if(close_hs) begin
                // PHY valid can stay high into trail: reproduce board regression.
                repeat(24) begin @(negedge clk);data=0;end
                @(negedge clk);hs=0;repeat(80) @(negedge clk);
            end
        end
    endtask
    initial begin
        repeat(20) @(negedge clk);rst_n=1;repeat(100) @(negedge clk);
        // FS shares HS with the first line; FE shares HS with the last line.
        short_packet(0,0);
        for(integer row=0;row<1944;row=row+1) raw_line(row,row!=1943);
        short_packet(1);repeat(2000) @(negedge clk);
        if(rxdiag[63:32]!=1 || npacked!=388800 || sof!=1 || counts!=1 || !published || writes!=388800)
            $fatal(1,"full pipeline failed: RX=%h packed=%0d sof=%0d cap=%h diag=%h writes=%0d",rxdiag,npacked,sof,counts,cdiag,writes);
        // A missing FE can be bounded by the next FS, provided all raw lines
        // and all ISP words are complete. PHY comparison warnings must not
        // defeat geometry checks or prevent publication.
        matcherr=1;short_packet(0);
        for(integer row=0;row<1944;row=row+1) raw_line(row);
        short_packet(0);repeat(2000) @(negedge clk);
        if(rxdiag[63:32]!=2 || rxdiag[31:24]!=8'h12 || counts!=2 ||
           npacked!=777600 || writes!=777600 || sof!=2 || nonzero_words==0)
            $fatal(1,"complete next-FS boundary failed RX=%h cap=%h words=%0d writes=%0d SOF=%0d",rxdiag,counts,npacked,writes,sof);
        // The previous FS already started this frame. Reproduce the board's
        // 92-word truncated final RAW row, outside the 1920x1080 display crop.
        for(integer row=0;row<1943;row=row+1) raw_line(row);
        // Board also misses FE: the next FS must finalize this tail-fault frame.
        short_line();short_packet(0);repeat(2000) @(negedge clk);
        if(rxdiag[63:48]!=1 || counts!=3 || npacked!=1166400 || writes!=1166400)
            $fatal(1,"tail fault wrongly discarded complete crop RX=%h cap=%h words=%0d",rxdiag,counts,npacked);
        // The same fault before the crop must still reject the image even
        // if subsequent packing happens to produce the expected word count.
        // The previous FS already started the next frame.
        short_line();
        for(integer row=1;row<1944;row=row+1) raw_line(row);
        short_packet(1);repeat(2000) @(negedge clk);
        if(counts!=32'h00010003) $fatal(1,"prefix fault was accepted cap=%h",counts);
        short_packet(0);
        for(integer row=0;row<1944;row=row+1) begin
            if(row==1000) short_line();else raw_line(row);
        end
        short_packet(1);repeat(2000) @(negedge clk);
        if(counts!=32'h00020003) $fatal(1,"visible-region fault was accepted cap=%h",counts);
        $display("PASS full CSI->RAW->ISP->capture: full crops publish despite truncated last RAW row; prefix and visible-region faults rejected; shared-HS and next-FS fallback pass");
        $finish;
    end
    task short_line;
        begin
            @(negedge clk);hs=1;data=16'h2ba8;
            @(negedge clk);data=16'h0c3b;
            repeat(184) begin @(negedge clk);data=16'h8080;end
            @(negedge clk);hs=0;repeat(80) @(negedge clk);
        end
    endtask
    initial begin #200000000;$fatal(1,"timeout");end
endmodule

// Ports/latency match the generated TD line-memory wrappers.
module blk_mem_gen_zhenghe(input clka,clkb,wea,web,input [10:0] addra,addrb,
    input [31:0] dia,dib,output reg [31:0] doa,dob);
    reg [31:0] mem[0:2047];
    always @(posedge clka) begin doa<=mem[addra];if(wea)mem[addra]<=dia;end
    always @(posedge clkb) begin dob<=mem[addrb];if(web)mem[addrb]<=dib;end
endmodule
module blk_mem_gen_demosaic(input clka,clkb,wea,web,input [10:0] addra,addrb,
    input [32:0] dia,dib,output reg [32:0] doa,dob);
    reg [32:0] mem[0:2047];
    always @(posedge clka) begin doa<=mem[addra];if(wea)mem[addra]<=dia;end
    always @(posedge clkb) begin dob<=mem[addrb];if(web)mem[addrb]<=dib;end
endmodule
module blk_mem_gen_awb_delay_signal(input clka,clkb,wea,web,input [10:0] addra,addrb,
    input [95:0] dia,dib,output reg [95:0] doa,dob);
    reg [95:0] mem[0:2047];
    always @(posedge clka) begin doa<=mem[addra];if(wea)mem[addra]<=dia;end
    always @(posedge clkb) begin dob<=mem[addrb];if(web)mem[addrb]<=dib;end
endmodule
