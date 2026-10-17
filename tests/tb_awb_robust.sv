`timescale 1ns/1ps
module tb_awb_robust;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,fs=0,valid=0,bypass=0,gate=0,smooth=0;
    reg [7:0] black=0,threshold=64;
    reg [95:0] data=0,expected=0;
    wire [95:0] result;
    wire outvalid,outfs,outlast,ready;
    awb #(.IMG_WIDTH(64),.IMG_HEIGHT(16)) dut(
        .I_clk(clk),.I_rst_n(rst),.I_tlast(1'b0),.I_tuser(fs),.I_tdata(data),
        .I_tvalid(valid),.I_tready(ready),.I_bypass(bypass),.I_blc_off(black),
        .I_gate_en(gate),.I_gate_th(threshold),.I_smooth_en(smooth),
        .O_tlast(outlast),.O_tuser(outfs),.O_tdata(result),.O_tvalid(outvalid),.O_tready(1'b1));
    reg [95:0] q[0:3];reg [3:0] vq=0,fq=0;
    reg [19:0] observed_r=65536,observed_b=65536;
    integer checked=0,k;
    always @(posedge clk) begin
        if(!rst) begin vq=0;fq=0;observed_r=65536;observed_b=65536;end
        else begin
            for(k=3;k>0;k=k-1) q[k]=q[k-1];q[0]=expected;
            vq={vq[2:0],valid};fq={fq[2:0],fs};
            #1;
            if(outvalid!==vq[3]) $fatal(1,"valid pipeline changed");
            if(outfs!==fs || ready!==1 || outlast!==(!vq[2] && vq[3]))
                $fatal(1,"legacy stream control changed");
            if(outvalid) begin
                if(result!==q[3]) $fatal(1,"pixel mismatch at sample %0d: got %h expected %h",checked,result,q[3]);
                checked=checked+1;
            end
            if((dut.in_r_r1!=observed_r || dut.in_b_r1!=observed_b) && !fq[2])
                $fatal(1,"gain changed inside a frame");
            observed_r=dut.in_r_r1;observed_b=dut.in_b_r1;
        end
    end
    integer gr=65536,gb=65536,pr=65536,pb=65536,pvalid=0;
    integer prev_r=0,prev_g=0,prev_b=0,prev_count=0;
    integer prev_dirty=1;
    reg [18:0] prev_cfg=0,pcfg=0;
    function [23:0] pattern(input integer kind,input integer index);
        case(kind)
            0:pattern={8'd80,8'd120,8'd100};
            1:pattern={8'd100,8'd120,8'd110};
            2:pattern={8'd220,8'd50,8'd40};
            3:pattern=(index%5==0)?{8'd80,8'd120,8'd100}:{8'd220,8'd50,8'd40};
            4:pattern={8'd252,8'd200,8'd180};
            5:pattern={8'd20,8'd24,8'd18};
            6:pattern=(index<5)?{8'd80,8'd120,8'd100}:{8'd220,8'd50,8'd40};
            7:pattern={8'd50,8'd60,8'd55};
            8:pattern={8'd89,8'd120,8'd100};
            9:pattern={8'd120,8'd100,8'd60};
            default:pattern={8'd100,8'd100,8'd100};
        endcase
    endfunction
    function [23:0] corrected(input [23:0] px);
        integer r,g,b;
        begin
            r=px[23:16]>black?px[23:16]-black:0;
            g=px[15:8]>black?px[15:8]-black:0;
            b=px[7:0]>black?px[7:0]-black:0;
            r=(r*gr)/65536;b=(b*gb)/65536;
            if(r>255)r=255;if(b>255)b=255;
            corrected={r[7:0],g[7:0],b[7:0]};
        end
    endfunction
    task send_frame(input integer kind,input integer bubbles,input integer dirty);
        integer n,l,r,g,b,mx,mn,sr,sg,sb,count;
        reg [23:0] px;
        reg [18:0] cfg;
        reg initial_gate;
        begin
            cfg={black,threshold,gate,smooth,bypass};initial_gate=gate;
            if(bypass) begin gr=65536;gb=65536;end
            else if(pvalid && pcfg==cfg) begin
                gr=smooth ? gr+(($signed(pr)-$signed(gr))>>>3):pr;
                gb=smooth ? gb+(($signed(pb)-$signed(gb))>>>3):pb;
            end
            pvalid=0;sr=0;sg=0;sb=0;count=0;
            for(n=0;n<256;n=n+1) begin
                @(negedge clk);
                if(dirty && n==128)gate=!gate;
                if(dirty && n==200)gate=initial_gate;
                fs=(n==0);valid=1;
                px=pattern(kind,n);
                // Lane zero controls statistics; the other lanes deliberately
                // differ to check shared gains and clipping on every output.
                data={24'hff6030,24'h204080,24'h010203,px};
                for(l=0;l<4;l=l+1) expected[l*24+:24]=corrected(data[l*24+:24]);
                r=px[23:16]>black?px[23:16]-black:0;
                g=px[15:8]>black?px[15:8]-black:0;
                b=px[7:0]>black?px[7:0]-black:0;
                mx=r>g?r:g;if(b>mx)mx=b;
                mn=r<g?r:g;if(b<mn)mn=b;
                if(px[23:16]<250 && px[15:8]<250 && px[7:0]<250 &&
                   mx>=32 && mx<=240 && mn>=8 && 2*(mx-mn)<=mx &&
                   (!gate || (mx-mn)*256<=mx*threshold)) begin
                    sr=sr+r;sg=sg+g;sb=sb+b;count=count+1;
                end
                if(bubbles && n%17==16) begin @(negedge clk);valid=0;fs=0;data=0;end
            end
            // A software reference of the two-frame statistics/commit delay.
            if(!bypass && !prev_dirty && prev_cfg==cfg && prev_count>=16) begin
                pr=(64'(prev_g)*65536)/prev_r;pb=(64'(prev_g)*65536)/prev_b;
                if(pr<32768)pr=32768;if(pr>262144)pr=262144;
                if(pb<32768)pb=32768;if(pb>262144)pb=262144;
                pcfg=cfg;pvalid=1;
            end
            prev_r=sr;prev_g=sg;prev_b=sb;prev_count=count;prev_cfg=cfg;prev_dirty=dirty;
            // Finish sampling the final input before the caller changes controls.
            @(posedge clk); #2;
        end
    endtask
    integer n;
    initial begin
        repeat(4) @(negedge clk);rst=1;
        repeat(4) send_frame(0,0,0);
        if(gr!=98304 || gb!=78643)$fatal(1,"non-unity neutral calibration failed");
        $display("PASS AWB independent fixed-point model, four lanes, clipping, first pixel and back-to-back frames");
        repeat(4) send_frame(3,1,0);
        if(gr!=98304 || gb!=78643)$fatal(1,"red majority contaminated gains");
        repeat(4) send_frame(2,0,0);
        repeat(4) send_frame(5,0,0);
        repeat(4) send_frame(6,0,0);
        if(gr!=98304 || gb!=78643)$fatal(1,"invalid/insufficient samples changed gains");
        $display("PASS red-majority rejection and gain hold for all-red, darkness and insufficient neutral samples");
        black=32;repeat(4) send_frame(4,0,0);
        if(gr!=98304 || gb!=78643)$fatal(1,"black subtraction hid raw clipping");
        bypass=1;repeat(3) send_frame(2,0,0);
        if(gr!=65536 || gb!=65536)$fatal(1,"OFF did not restore unity");
        bypass=0;black=0;gate=1;
        repeat(4) send_frame(1,0,0);
        if(gr!=78643 || gb!=71493)$fatal(1,"GRAY calibration failed");
        repeat(4) send_frame(7,0,0);
        if(gr!=78643 || gb!=71493)$fatal(1,"GRAY brightness invariance failed");
        repeat(4) send_frame(8,0,0);
        if(gr!=78643 || gb!=71493)$fatal(1,"relative threshold boundary failed");
        $display("PASS pre-BLACK clipping guard, OFF behavior, stale candidate rejection and relative GRAY gate");
        gate=0;smooth=1;
        repeat(16) send_frame(0,1,0);
        if(gr<=78643 || gr>=98304)$fatal(1,"IIR did not converge gradually");
        // Invalid profiles cannot contaminate an estimate when controls change
        // mid-frame and later return to the same values.
        repeat(4) send_frame(2,0,0);
        send_frame(9,0,1);
        repeat(4) send_frame(2,0,0);
        $display("PASS 1/8 IIR, frame-atomic commits, valid bubbles and dirty-frame exclusion");
        smooth=0;repeat(5) send_frame(9,0,0);
        if(gr!=54613 || gb!=109226)$fatal(1,"AUTO direct estimate failed");
        repeat(4) send_frame(2,0,0);
        if(gr!=54613 || gb!=109226)$fatal(1,"AUTO reset gains on invalid frame");
        @(negedge clk);valid=0;fs=0;
        repeat(8) @(negedge clk);
        $display("PASS AWB robust: %0d output words checked; AUTO holds previous gain",checked);
        $finish;
    end
    initial begin #10000000;$fatal(1,"AWB test timeout");end
endmodule
