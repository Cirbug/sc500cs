`timescale 1ns/1ps
module tb_ui_osd;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg vsync = 0;
    reg hsync = 0;
    reg de = 0;
    reg menu_enable = 1;
    reg [23:0] data = 24'h526879;
    wire out_vsync, out_hsync, out_de;
    wire [23:0] out_data;
    integer px, py, mode, fd, line_index, char_index;
    integer start_y, last_x;
    integer hits [0:39];
    reg [23:0] sample;
    reg [23:0] block_row [0:511];

    ui_osd dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vsync),
        .I_hsync(hsync), .I_de(de), .I_data(data),
        .I_menu_enable(menu_enable), .I_edit_enable(1'b0),
        .I_info_enable(1'b1), .I_menu_index(2'd3),
        .I_exposure(16'd2240), .I_gain(16'd80),
        .O_vsync(out_vsync), .O_hsync(out_hsync),
        .O_de(out_de), .O_data(out_data)
    );

    task tick;
        begin
            @(posedge clk); #1;
            if ({out_vsync, out_hsync, out_de} !== {vsync, hsync, de})
                $fatal(1, "Video controls lost alignment");
            if (!de && out_data !== 24'd0)
                $fatal(1, "Nonzero blanking pixel");
            @(negedge clk);
        end
    endtask

    initial begin
        fd = $fopen("ui_osd_preview.ppm", "w");
        if (!fd) $fatal(1, "Cannot open preview output");
        $fwrite(fd, "P3\n512 320\n255\n");
        for (px = 0; px < 40; px = px + 1) hits[px] = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;
        for (mode = 0; mode < 2; mode = mode + 1) begin
            menu_enable = (mode == 0);
            vsync = 1; tick;
            vsync = 0; tick;
            for (py = 0; py < 1080; py = py + 1) begin
                de = 1;
                for (px = 0; px < 1920; px = px + 1) begin
                    tick;
                    if (!menu_enable || px < 24 || px >= 492 || py < 24 || py >= 300)
                        if (out_data !== data)
                            $fatal(1, "Video passthrough mismatch at %0d,%0d", px, py);
                    if (mode == 0) begin
                        if (px < 512 && py < 320)
                            $fwrite(fd, "%0d %0d %0d\n", out_data[23:16], out_data[15:8], out_data[7:0]);
                        line_index = -1;
                        if (py >= 40 && py < 68) line_index = 0;
                        if (py >= 76 && py < 104) line_index = 1;
                        if (py >= 112 && py < 140) line_index = 2;
                        if (py >= 148 && py < 176) line_index = 3;
                        if (py >= 184 && py < 212) line_index = 4;
                        last_x = (line_index == 1) ? 288 : 160;
                        if (out_data === 24'hffffff) begin
                            if (line_index < 0 || px < 44 || px >= last_x)
                                $fatal(1, "Repeated or out-of-bounds text at %0d,%0d", px, py);
                            char_index = (px - 44) / 32;
                            hits[line_index * 8 + char_index] = hits[line_index * 8 + char_index] + 1;
                        end
                        // Each font dot must form a solid square, without missing rows.
                        if (line_index >= 0 && px >= 44 && px < 300) begin
                            start_y = 40 + line_index * 36;
                            if ((px - 44) % 4 == 0) sample = out_data;
                            else if (out_data !== sample)
                                $fatal(1, "Uneven horizontal font scaling");
                            if ((py - start_y) % 4 == 0) block_row[px] = out_data;
                            else if (out_data !== block_row[px])
                                $fatal(1, "Uneven vertical font scaling");
                        end
                    end
                end
                de = 0; hsync = 1; tick;
                hsync = 0; tick;
            end
        end
        for (line_index = 0; line_index < 5; line_index = line_index + 1)
            for (char_index = 0; char_index < 8; char_index = char_index + 1) begin
                if (line_index == 1 || char_index < 4) begin
                    if (hits[line_index * 8 + char_index] == 0)
                        $fatal(1, "Missing menu character");
                end else if (hits[line_index * 8 + char_index] != 0)
                    $fatal(1, "Unexpected extra menu character");
            end
        $fclose(fd);
        $display("PASS: five labels, no repeated text, square font dots, video passthrough and control alignment");
        $finish;
    end
endmodule
