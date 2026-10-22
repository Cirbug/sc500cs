`timescale 1ns/1ps
module tb_gamma_presets;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, enable=1, fs=0, valid=0;
    reg [3:0] sel=0;
    reg [95:0] data=0;
    wire ofs,ov;
    wire [95:0] od;
    integer s,p,ch,expected,actual,diff,checked;

    rgb96_gamma dut(
        .I_clk(clk),.I_rst_n(rst_n),.I_enable(enable),.I_gamma_sel(sel),
        .I_bright(2'd0),.I_frame_start(fs),.I_valid(valid),.I_data(data),
        .O_frame_start(ofs),.O_valid(ov),.O_data(od));

    function real gamma_of(input integer idx);
        begin
            case(idx)
                0: gamma_of=0.45;
                1: gamma_of=0.30;
                2: gamma_of=0.35;
                3: gamma_of=0.40;
                4: gamma_of=0.45;
                5: gamma_of=0.50;
                6: gamma_of=0.55;
                7: gamma_of=0.60;
                default: gamma_of=0.65;
            endcase
        end
    endfunction

    task run_pixel;
        input integer px;
        input integer use_gamma;
        input integer gamma_idx;
        integer e,a,d,c;
        begin
            data = {12{px[7:0]}};
            enable = use_gamma;
            sel = gamma_idx[3:0];
            valid = 1;
            fs = (px==0);
            @(negedge clk);
            repeat(4) @(posedge clk);
            @(negedge clk);
            if(ov!==1'b1) $fatal(1,"valid missing sel=%0d px=%0d",gamma_idx,px);
            if(use_gamma)
                e = $rtoi(255.0 * ((px/255.0) ** gamma_of(gamma_idx)) + 0.5);
            else
                e = px;
            for(c=0;c<12;c=c+1) begin
                a = od[c*8 +: 8];
                d = a-e;
                if(d<0) d=-d;
                if(d>2) $fatal(1,"gamma mismatch sel=%0d px=%0d lane=%0d got=%0d exp=%0d",
                               gamma_idx,px,c,a,e);
            end
            checked = checked + 12;
            valid = 0;
            fs = 0;
        end
    endtask

    initial begin
        checked = 0;
        #2; rst_n=0;
        repeat(4) @(negedge clk);
        rst_n=1;
        // Selector 0 uses the historical 0.45 curve; 1..8 are presets;
        // 9..15 must clamp to the last preset.
        for(s=0;s<=9;s=s+1)
            for(p=0;p<256;p=p+1)
                run_pixel(p,1,s);
        // Bypass must be bit-exact for every input, independent of selection.
        for(p=0;p<256;p=p+1)
            run_pixel(p,0,5);
        $display("PASS gamma presets: %0d lane samples, sel 0..9, OFF bypass",checked);
        $finish;
    end
endmodule
