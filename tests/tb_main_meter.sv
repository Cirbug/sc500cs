`timescale 1ns/1ps
module tb_main_meter;
    reg clk=0,src_clk=0,rst=0,fs=0,vs=0,src_run=1;
    always #5 clk=~clk;
    always #7 if(src_run) src_clk=~src_clk;
    wire [11:0] mf,hf;
    wire [31:0] mt,ht;
    wire valid; video_dual_frame_stats #(.PIXEL_CLOCK_HZ(30000)) dut(clk,rst,vs,src_clk,fs,ht,mt,hf,mf,valid);
    function integer dec;
        input [31:0] n;
        integer k,p;
        begin dec=0;p=1;for(k=0;k<8;k=k+1)begin dec=dec+n[k*4+:4]*p;p=p*10;end end
    endfunction
    integer sec,k,period,expected_m=0,expected_h=0;
    initial begin
        repeat(5) @(negedge clk);
        rst=1;
        for(sec=0;sec<6;sec=sec+1) begin
            period=(sec<2)?1000:2000;
            if(sec==4)src_run=0;
            if(sec==5)src_run=1;
            for(k=0;k<30000;k=k+1)begin
                // Multi-cycle pulses must count once; phase is asynchronous to source clock.
                fs=(sec!=4 && k%period>=10 && k%period<20);
                vs=(k%500>=50 && k%500<56);
                if(sec!=4 && k%period==10)expected_m=expected_m+1;
                if(k%500==50)expected_h=expected_h+1;
                @(posedge clk);#1;
                if((^{mf,hf,mt,ht})===1'bx)$fatal(1,"unknown counter");
                @(negedge clk);
            end
            if(dec(mt)!=expected_m || dec(ht)!=expected_h)$fatal(1,"count mismatch sec %0d M %0d/%0d H %0d/%0d",sec,dec(mt),expected_m,dec(ht),expected_h);
            if(dec({20'd0,mf})!=((sec<2)?30:(sec==4?0:15)) || dec({20'd0,hf})!=60)$fatal(1,"FPS mismatch sec %0d mf=%h hf=%h",sec,mf,hf);
            $display("SECOND %0d MIPI=%0d HDMI=%0d TOTAL=%0d/%0d",sec,dec({20'd0,mf}),dec({20'd0,hf}),dec(mt),dec(ht));
        end
        // BCD decimal carry and wrap, including simultaneous second-boundary event.
        fs=0;vs=0;repeat(10)@(negedge clk);
        dut.hdmi_frames=32'h99999999;
        dut.ticks=29999;dut.hw=12'h059;
        vs=1;@(posedge clk);#1;
        if(ht!==32'h99999999 || hf!==12'h060)$fatal(1,"boundary frame lost or decimal wrap failed");
        @(negedge clk);vs=0;repeat(2)@(negedge clk);
        dut.ticks=29999;dut.hw=12'h999;
        vs=1;@(posedge clk);#1;if(hf!==12'h999)$fatal(1,"FPS saturation failed");
        // Reset during activity clears totals and discards a partial FPS window.
        @(negedge clk);rst=0;fs=0;vs=0;
        repeat(4)@(negedge clk);rst=1;
        repeat(20)@(negedge clk);
        if({mf,hf,mt,ht}!==0)$fatal(1,"reset failed");
        $display("PASS METER: asynchronous events, 30/15/0 FPS, stalled source clock, restart, wide VS, BCD carry/saturation, boundary inclusion, saturation, reset");
        $finish;
    end
    initial begin #10000000;$fatal(1,"timeout");end
endmodule

