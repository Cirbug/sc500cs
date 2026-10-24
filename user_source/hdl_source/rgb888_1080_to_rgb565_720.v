// Side branch for the PH1P35 -> EG4D20 link.
// Input: four packed RGB888 pixels per beat, 1920x1080.
// Output: four RGB565 pixels per beat, 1280x720.
// Each 3-source-pixel interval is integrated into two half-width pixels with
// 2:1 edge weights. RGB565 is stored in the line buffer to keep this side
// branch small; vertical integration therefore rounds at RGB565 precision.
module rgb888_1080_to_rgb565_720 #(
    parameter integer OUT_WORDS = 320,
    parameter integer OUT_HEIGHT = 720,
    parameter integer ADDR_WIDTH = 9
) (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_frame_start,
    input  wire        I_line_end,
    input  wire        I_valid,
    input  wire [95:0] I_rgb888,
    output reg         O_frame_start,
    output reg         O_line_end,
    output reg         O_frame_end,
    output reg         O_valid,
    output reg  [63:0] O_rgb565
);

    function [23:0] mix_2a_1b;
        input [23:0] a;
        input [23:0] b;
        reg [9:0] r, g, bl;
        begin
            r  = (2 * a[23:16] + b[23:16] + 1) / 3;
            g  = (2 * a[15:8]  + b[15:8]  + 1) / 3;
            bl = (2 * a[7:0]   + b[7:0]   + 1) / 3;
            mix_2a_1b = {r[7:0], g[7:0], bl[7:0]};
        end
    endfunction

    function [23:0] mix_1a_2b;
        input [23:0] a;
        input [23:0] b;
        begin
            mix_1a_2b = mix_2a_1b(b, a);
        end
    endfunction

    function [15:0] mix_rgb565_2a1b;
        input [15:0] a;
        input [15:0] b;
        input        reverse_weights;
        reg [6:0] r;
        reg [7:0] g;
        reg [6:0] bl;
        reg [4:0] ro,bo;
        reg [5:0] go;
        begin
            if(reverse_weights) begin
                r  = a[15:11] + 2*b[15:11];
                g  = a[10:5]  + 2*b[10:5];
                bl = a[4:0]   + 2*b[4:0];
            end else begin
                r  = 2*a[15:11] + b[15:11];
                g  = 2*a[10:5]  + b[10:5];
                bl = 2*a[4:0]   + b[4:0];
            end
            ro = (r+1)/3;
            go = (g+1)/3;
            bo = (bl+1)/3;
            mix_rgb565_2a1b = {ro,go,bo};
        end
    endfunction

    function [63:0] vertical_mix565x4;
        input [63:0] a;
        input [63:0] b;
        input        reverse_weights;
        begin
            vertical_mix565x4 = {
                mix_rgb565_2a1b(a[63:48],b[63:48],reverse_weights),
                mix_rgb565_2a1b(a[47:32],b[47:32],reverse_weights),
                mix_rgb565_2a1b(a[31:16],b[31:16],reverse_weights),
                mix_rgb565_2a1b(a[15:0],b[15:0],reverse_weights)
            };
        end
    endfunction

    function [15:0] rgb888_to_rgb565;
        input [23:0] p;
        begin
            rgb888_to_rgb565 = {p[23:19], p[15:10], p[7:3]};
        end
    endfunction

    function [63:0] rgb888x4_to_rgb565x4;
        input [95:0] p;
        begin
            rgb888x4_to_rgb565x4 = {
                rgb888_to_rgb565(p[95:72]),
                rgb888_to_rgb565(p[71:48]),
                rgb888_to_rgb565(p[47:24]),
                rgb888_to_rgb565(p[23:0])
            };
        end
    endfunction

    reg [23:0] h_carry0, h_carry1;
    reg [1:0]  h_carry_count;
    reg [23:0] h_pending0, h_pending1, h_pending2;
    reg [1:0]  h_pending_count;
    reg [1:0]  src_y_mod3;
    reg [ADDR_WIDTH-1:0] h_word_index;
    reg [9:0]  out_y;

    reg [23:0] src_list [0:5];
    reg [23:0] h_list [0:3];
    reg [23:0] merge_list [0:6];
    reg [2:0]  src_count;
    reg [2:0]  h_count;
    reg [2:0]  merge_count;
    reg [1:0]  next_carry_count;
    reg [23:0] next_carry0, next_carry1;
    reg [1:0]  next_pending_count;
    reg [23:0] next_pending0, next_pending1, next_pending2;
    reg        h_word_valid;
    reg [95:0] h_word;
    reg [1:0]  h_y_mod3;
    integer i, j;

    // Expand the four-lane input to complete groups of three, then fold each
    // group into two weighted pixels. At most four output pixels are created
    // per input beat; remainders are carried to the following beat.
    always @* begin
        for(i=0;i<6;i=i+1) src_list[i] = 24'd0;
        src_count = 3'd0;
        if(I_frame_start) begin
            src_list[0]=I_rgb888[95:72]; src_list[1]=I_rgb888[71:48];
            src_list[2]=I_rgb888[47:24]; src_list[3]=I_rgb888[23:0];
            src_count=3'd4;
        end else begin
            case(h_carry_count)
                2'd0: begin
                    src_list[0]=I_rgb888[95:72]; src_list[1]=I_rgb888[71:48];
                    src_list[2]=I_rgb888[47:24]; src_list[3]=I_rgb888[23:0];
                    src_count=3'd4;
                end
                2'd1: begin
                    src_list[0]=h_carry0; src_list[1]=I_rgb888[95:72];
                    src_list[2]=I_rgb888[71:48]; src_list[3]=I_rgb888[47:24];
                    src_list[4]=I_rgb888[23:0]; src_count=3'd5;
                end
                default: begin
                    src_list[0]=h_carry0; src_list[1]=h_carry1;
                    src_list[2]=I_rgb888[95:72]; src_list[3]=I_rgb888[71:48];
                    src_list[4]=I_rgb888[47:24]; src_list[5]=I_rgb888[23:0];
                    src_count=3'd6;
                end
            endcase
        end

        for(i=0;i<4;i=i+1) h_list[i] = 24'd0;
        h_count = 3'd0;
        for(j=0;j<2;j=j+1) begin
            if((j*3+2) < src_count) begin
                h_list[j*2]   = mix_2a_1b(src_list[j*3], src_list[j*3+1]);
                h_list[j*2+1] = mix_1a_2b(src_list[j*3+1], src_list[j*3+2]);
                h_count = h_count + 3'd2;
            end
        end

        next_carry_count = 2'd0;
        next_carry0 = 24'd0;
        next_carry1 = 24'd0;
        if(!I_line_end) begin
            case(src_count)
                3'd4: begin next_carry_count=2'd1; next_carry0=src_list[3]; end
                3'd5: begin next_carry_count=2'd2; next_carry0=src_list[3]; next_carry1=src_list[4]; end
                default: begin next_carry_count=2'd0; end
            endcase
        end

        for(i=0;i<7;i=i+1) merge_list[i] = 24'd0;
        merge_count = 3'd0;
        if(!I_frame_start) begin
            case(h_pending_count)
                2'd1: begin merge_list[0]=h_pending0; merge_count=1; end
                2'd2: begin merge_list[0]=h_pending0; merge_list[1]=h_pending1; merge_count=2; end
                2'd3: begin merge_list[0]=h_pending0; merge_list[1]=h_pending1; merge_list[2]=h_pending2; merge_count=3; end
                default: begin end
            endcase
        end
        for(i=0;i<4;i=i+1) begin
            if(i < h_count) begin
                merge_list[merge_count] = h_list[i];
                merge_count = merge_count + 1'b1;
            end
        end

        h_word_valid = I_valid && (merge_count >= 4);
        h_word = {merge_list[0],merge_list[1],merge_list[2],merge_list[3]};
        h_y_mod3 = I_frame_start ? 2'd0 : src_y_mod3;
        if(merge_count >= 4) begin
            next_pending_count = merge_count - 4;
            next_pending0 = merge_list[4];
            next_pending1 = merge_list[5];
            next_pending2 = merge_list[6];
        end else begin
            next_pending_count = merge_count[1:0];
            next_pending0 = merge_list[0];
            next_pending1 = merge_list[1];
            next_pending2 = merge_list[2];
        end
        if(I_line_end) begin
            next_pending_count = 2'd0;
            next_pending0 = 24'd0; next_pending1 = 24'd0; next_pending2 = 24'd0;
        end
    end

    // One 1280-pixel horizontal line in RGB888. Row 0 is stored; row 1 is
    // averaged with it and replaces it; row 2 is averaged with stored row 1.
    reg [63:0] line_ram [0:OUT_WORDS-1];
    reg [63:0] old_word_q, current_word_q;
    reg [ADDR_WIDTH-1:0] word_index_q;
    reg [1:0] y_mod3_q;
    reg word_valid_q;

    always @(posedge I_clk) begin
        if(I_valid && h_word_valid) begin
            old_word_q <= line_ram[h_word_index];
            current_word_q <= rgb888x4_to_rgb565x4(h_word);
            word_index_q <= h_word_index;
            y_mod3_q <= h_y_mod3;
            word_valid_q <= 1'b1;
            if(h_y_mod3 != 2'd2)
                line_ram[h_word_index] <= rgb888x4_to_rgb565x4(h_word);
        end else begin
            word_valid_q <= 1'b0;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            h_carry0 <= 24'd0; h_carry1 <= 24'd0; h_carry_count <= 2'd0;
            h_pending0 <= 24'd0; h_pending1 <= 24'd0; h_pending2 <= 24'd0;
            h_pending_count <= 2'd0; src_y_mod3 <= 2'd0; h_word_index <= {ADDR_WIDTH{1'b0}};
        end else begin
            if(I_frame_start) begin
                h_carry_count <= 2'd0; h_pending_count <= 2'd0;
                src_y_mod3 <= 2'd0; h_word_index <= {ADDR_WIDTH{1'b0}};
            end
            if(I_valid) begin
                h_carry0 <= next_carry0; h_carry1 <= next_carry1;
                h_carry_count <= next_carry_count;
                h_pending0 <= next_pending0; h_pending1 <= next_pending1;
                h_pending2 <= next_pending2; h_pending_count <= next_pending_count;
                if(h_word_valid) begin
                    if(h_word_index == OUT_WORDS-1)
                        h_word_index <= {ADDR_WIDTH{1'b0}};
                    else
                        h_word_index <= h_word_index + 1'b1;
                end
                if(I_line_end) begin
                    h_carry_count <= 2'd0; h_pending_count <= 2'd0;
                    h_word_index <= {ADDR_WIDTH{1'b0}};
                    src_y_mod3 <= (h_y_mod3 == 2'd2) ? 2'd0 : h_y_mod3 + 1'b1;
                end
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_frame_start <= 1'b0; O_line_end <= 1'b0; O_frame_end <= 1'b0;
            O_valid <= 1'b0; O_rgb565 <= 64'd0; out_y <= 10'd0;
        end else begin
            O_frame_start <= 1'b0; O_line_end <= 1'b0; O_frame_end <= 1'b0;
            O_valid <= 1'b0;
            if(I_frame_start)
                out_y <= 10'd0;
            if(word_valid_q && (y_mod3_q != 2'd0)) begin
                O_valid <= 1'b1;
                O_rgb565 <= vertical_mix565x4(old_word_q, current_word_q,
                                                y_mod3_q == 2'd2);
                if(word_index_q == 0 && out_y == 0)
                    O_frame_start <= 1'b1;
                if(word_index_q == OUT_WORDS-1) begin
                    O_line_end <= 1'b1;
                    if(out_y == OUT_HEIGHT-1) begin
                        O_frame_end <= 1'b1;
                        out_y <= 10'd0;
                    end else begin
                        out_y <= out_y + 1'b1;
                    end
                end
            end
        end
    end

endmodule
