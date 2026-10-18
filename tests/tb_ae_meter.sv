`timescale 1ns/1ps
module tb_ae_meter;
    reg clk=0,apb_clk=0,rst_n=0,valid=0,fs=0;
    always #5 clk=~clk;
    always #7 apb_clk=~apb_clk;
    reg [95:0] pixels=0;
    wire [7:0] r,g,b,frame_seq;
    wire [13:0] samples;
    wire [63:0] snapshot;
    dbg_color_stat meter(.I_clk(clk),.I_rst_n(rst_n),.I_frame_start(fs),.I_valid(valid),.I_data(pixels),
        .O_mean_r(r),.O_mean_g(g),.O_mean_b(b),.O_frame_cnt(frame_seq),.O_sample_count(samples));
    video_diag_cdc #(.WIDTH(64)) cdc(.src_clk(clk),.dst_clk(apb_clk),.rst_n(rst_n),
        .data({8'd0,frame_seq,2'd0,samples,8'd0,r,g,b}),.snapshot(snapshot));
    reg [19:0] addr=0;
    reg sel=0,en=0,write=0;
    reg [1:0] ready=0;
    wire [31:0] rd;
    mcu_ui_apb_regs apb(.I_clk(apb_clk),.I_rst(!rst_n),.I_button(4'hf),.I_usb_int_n(1'b1),
        .I_paddr(addr),.I_psel(sel),.I_penable(en),.I_pwrite(write),.I_pwdata(32'hffffffff),.I_pstrobe(4'hf),
        .I_ae_rgb(snapshot[23:0]),.I_ae_meta(snapshot[63:32]),.I_ae_sensor_ready(ready),.O_prdata(rd));
    task read_check(input [7:0] a,input [31:0] expected);
        begin
            @(negedge apb_clk);addr=a;sel=1;en=1;write=0;#1;
            if(rd!==expected)$fatal(1,"AE APB %h got=%h expected=%h",a,rd,expected);
            @(negedge apb_clk);sel=0;en=0;
        end
    endtask
    task frame(input [7:0] gray);
        integer expected;
        begin
            @(negedge clk);pixels={12{gray}};valid=1;
            repeat(518400) @(negedge clk);
            valid=0;repeat(4) @(negedge clk);
            fs=1;@(negedge clk);fs=0;
            expected=(gray*4050)/8192;
            if(samples!==14'd4050 || r!==expected || g!==expected || b!==expected)
                $fatal(1,"AE sample normalization input: count=%d rgb=%h/%h/%h gray=%d",samples,r,g,b,gray);
            repeat(30) @(negedge apb_clk);
            read_check(8'he0,{8'd0,r,g,b});
            read_check(8'he4,{8'd0,frame_seq,2'd0,samples});
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst_n=1;
        read_check(8'hdc,32'h41454d31);read_check(8'he8,0);
        ready=3;repeat(4) @(negedge apb_clk);read_check(8'he8,3);
        @(negedge clk);fs=1;@(negedge clk);fs=0;
        frame(128);frame(240);frame(0);
        @(negedge apb_clk);addr=8'he0;sel=1;en=1;write=1;
        @(negedge apb_clk);sel=0;en=0;write=0;
        read_check(8'he0,0);
        ready=0;repeat(4) @(negedge apb_clk);read_check(8'he8,0);
        $display("PASS AE metering: 4050 full-frame samples, RGB/count/frame_seq coherent CDC, APB capability/read-only data, sensor-ready synchronization");
        $finish;
    end
endmodule
