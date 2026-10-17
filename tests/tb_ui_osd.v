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
    integer clock_hits;
    integer hits [0:39];
    reg [23:0] sample;
    reg [23:0] block_row [0:511];

    ui_osd #(.MENU_CHINESE(0)) dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vsync),
        .I_hsync(hsync), .I_de(de), .I_data(data),
        .I_menu_enable(menu_enable), .I_edit_enable(1'b0),
        .I_info_enable(1'b1), .I_menu_index(3'd3),
        .I_picture_page(1'b0), .I_picture_ctrl(16'h1050),
        .I_record_status(32'd0),
        .I_exposure(16'd2240), .I_gain(16'd80),
        .I_rtc_hours(8'h12), .I_rtc_minutes(8'h34), .I_rtc_seconds(8'h56),
        .I_rtc_valid(1'b1), .I_rtc_error(1'b0), .I_rtc_osf(1'b0),
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
        clock_hits = 0;
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
                    if (!((menu_enable && px >= 24 && px < 492 && py >= 680 && py < 1004) ||
                          (px >= 24 && px < 220 && py >= 1016 && py < 1076) ||
                          (px >= 236 && px < 260 && py >= 1034 && py < 1058) ||
                          (px >= 818 && px < 1102 && py >= 16 && py < 60) || (px >= 1440 && px < 1904 && py >= 16 && py < 200)))
                        if (out_data !== data)
                            $fatal(1, "Video passthrough mismatch at %0d,%0d data=%06x expected=%06x menu=%b", px, py, out_data, data, menu_enable);
                    if (px >= 826 && px < 1082 && py >= 24 && py < 52 &&
                        out_data === 24'hffffff)
                        clock_hits = clock_hits + 1;
                    if (mode == 0) begin
                        if (px < 512 && py < 320)
                            $fwrite(fd, "%0d %0d %0d\n", out_data[23:16], out_data[15:8], out_data[7:0]);
                        line_index = -1;
                        if (py >= 696 && py < 724) line_index = 0;
                        if (py >= 732 && py < 760) line_index = 1;
                        if (py >= 768 && py < 796) line_index = 2;
                        if (py >= 804 && py < 832) line_index = 3;
                        if (py >= 840 && py < 868) line_index = 4;
                        last_x = (line_index == 1) ? 288 : (line_index == 3) ? 268 : 160;
                        if (out_data === 24'hffffff && px < 512 && py >= 680 && py < 868) begin
                            if (line_index < 0 || px < 44 || px >= last_x)
                                $fatal(1, "Repeated or out-of-bounds text at %0d,%0d", px, py);
                            char_index = (px - 44) / 32;
                            hits[line_index * 8 + char_index] = hits[line_index * 8 + char_index] + 1;
                        end
                        // Each font dot must form a solid square, without missing rows.
                        if (line_index >= 0 && px >= 44 && px < 300) begin
                            start_y = 696 + line_index * 36;
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
                if (line_index == 1 || (line_index == 3 && char_index < 7) ||
                    (line_index != 3 && char_index < 4)) begin
                    if (hits[line_index * 8 + char_index] == 0)
                        $fatal(1, "Missing menu character line=%0d char=%0d hits=%0d", line_index, char_index, hits[line_index * 8 + char_index]);
                end else if (hits[line_index * 8 + char_index] != 0)
                    $fatal(1, "Unexpected extra menu character");
            end
        if (clock_hits == 0)
            $fatal(1, "RTC clock text was not rendered in the upper-right panel");
        $fclose(fd);
        $display("PASS: five labels, no repeated text, square font dots, video passthrough and control alignment");
        $finish;
    end
endmodule
