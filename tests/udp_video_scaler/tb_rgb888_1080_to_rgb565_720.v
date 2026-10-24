`timescale 1ns/1ps
module tb_rgb888_1080_to_rgb565_720;
    localparam integer SRC_W=12;
    localparam integer SRC_H=6;
    localparam integer OUT_W=8;
    localparam integer OUT_H=4;
    localparam integer OUT_WORDS=OUT_W/4;

    reg clk=0, rst_n=0;
    reg frame_start=0, line_end=0, valid=0;
    reg [95:0] rgb888=0;
    wire frame_out, line_out, frame_end_out, valid_out;
    wire [63:0] rgb565;
    always #5 clk=~clk;

    rgb888_1080_to_rgb565_720 #(
        .OUT_WORDS(OUT_WORDS), .OUT_HEIGHT(OUT_H), .ADDR_WIDTH(2)
    ) dut(
        .I_clk(clk), .I_rst_n(rst_n), .I_frame_start(frame_start),
        .I_line_end(line_end), .I_valid(valid), .I_rgb888(rgb888),
        .O_frame_start(frame_out), .O_line_end(line_out), .O_frame_end(frame_end_out),
        .O_valid(valid_out), .O_rgb565(rgb565)
    );

    integer x, y, beat, errors, out_words, out_lines, out_frames, out_pixels;
    reg [15:0] expected [0:OUT_W*OUT_H-1];

    function [23:0] source_pixel(input integer xx, input integer yy);
        integer c;
        begin
            c=(xx*11+yy*17+20) & 255;
            source_pixel={c[7:0],c[7:0],c[7:0]};
        end
    endfunction

    function [23:0] mix21(input [23:0] a, input [23:0] b);
        integer r,g,bl;
        begin
            r=(2*a[23:16]+b[23:16]+1)/3;
            g=(2*a[15:8] +b[15:8] +1)/3;
            bl=(2*a[7:0]  +b[7:0]  +1)/3;
            mix21={r[7:0],g[7:0],bl[7:0]};
        end
    endfunction

    function [23:0] mix12(input [23:0] a, input [23:0] b);
        begin mix12=mix21(b,a); end
    endfunction

    function [23:0] horizontal_pixel(input integer xx, input integer yy);
        integer sx;
        begin
            sx=(xx/2)*3;
            if((xx%2)==0)
                horizontal_pixel=mix21(source_pixel(sx,yy),source_pixel(sx+1,yy));
            else
                horizontal_pixel=mix12(source_pixel(sx+1,yy),source_pixel(sx+2,yy));
        end
    endfunction

    function [15:0] horizontal_pixel565(input integer xx, input integer yy);
        reg [23:0] p;
        begin
            p=horizontal_pixel(xx,yy);
            horizontal_pixel565={p[23:19],p[15:10],p[7:3]};
        end
    endfunction

    function [15:0] expected_pixel(input integer xx, input integer yy);
        integer sy;
        integer r,g,b;
        reg [15:0] ha565,hb565;
        begin
            sy=(yy/2)*3;
            ha565=horizontal_pixel565(xx,sy+((yy%2)==0?0:1));
            hb565=horizontal_pixel565(xx,sy+((yy%2)==0?1:2));
            if((yy%2)==0) begin
                r=(2*ha565[15:11]+hb565[15:11]+1)/3;
                g=(2*ha565[10:5] +hb565[10:5] +1)/3;
                b=(2*ha565[4:0]  +hb565[4:0]  +1)/3;
            end else begin
                r=(ha565[15:11]+2*hb565[15:11]+1)/3;
                g=(ha565[10:5] +2*hb565[10:5] +1)/3;
                b=(ha565[4:0]  +2*hb565[4:0]  +1)/3;
            end
            expected_pixel={r[4:0],g[5:0],b[4:0]};
        end
    endfunction

    task send_beat(input integer yy, input integer xx, input integer first, input integer last);
        begin
            @(negedge clk);
            valid=1; frame_start=first; line_end=last;
            rgb888={source_pixel(xx,yy),source_pixel(xx+1,yy),
                    source_pixel(xx+2,yy),source_pixel(xx+3,yy)};
            @(negedge clk);
            valid=0; frame_start=0; line_end=0;
        end
    endtask

    always @(posedge clk) begin
        if(valid_out) begin
            if(frame_out !== (out_pixels==0)) begin
                $display("frame_start mismatch pixel=%0d",out_pixels); errors=errors+1;
            end
            for(integer lane=0; lane<4; lane=lane+1) begin
                if(rgb565[63-lane*16 -: 16] !== expected[out_pixels]) begin
                    $display("pixel mismatch idx=%0d got=%h exp=%h",out_pixels,
                             rgb565[63-lane*16 -: 16],expected[out_pixels]);
                    errors=errors+1;
                end
                out_pixels=out_pixels+1;
            end
            out_words=out_words+1;
            if(line_out) begin
                if(out_words!=OUT_WORDS) begin
                    $display("line word count=%0d",out_words); errors=errors+1;
                end
                out_words=0; out_lines=out_lines+1;
            end
            if(frame_end_out) out_frames=out_frames+1;
        end
    end

    initial begin
        errors=0; out_pixels=0; out_words=0; out_lines=0; out_frames=0;
        for(y=0;y<OUT_H;y=y+1)
            for(x=0;x<OUT_W;x=x+1)
                expected[y*OUT_W+x]=expected_pixel(x,y);

        repeat(4) @(negedge clk); rst_n=1;
        for(y=0;y<SRC_H;y=y+1)
            for(beat=0;beat<SRC_W/4;beat=beat+1)
                send_beat(y,beat*4,(y==0 && beat==0),(beat==SRC_W/4-1));
        repeat(5) @(negedge clk);

        if(out_pixels!=OUT_W*OUT_H) begin
            $display("output pixels=%0d expected=%0d",out_pixels,OUT_W*OUT_H); errors=errors+1;
        end
        if(out_lines!=OUT_H) begin
            $display("output lines=%0d expected=%0d",out_lines,OUT_H); errors=errors+1;
        end
        if(out_frames!=1) begin
            $display("output frames=%0d expected=1",out_frames); errors=errors+1;
        end
        if(errors==0) $display("RGB888_TO_RGB565_720_TEST_PASS");
        else $display("RGB888_TO_RGB565_720_TEST_FAIL errors=%0d",errors);
        $finish;
    end
endmodule
