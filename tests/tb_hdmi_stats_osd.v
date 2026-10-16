`timescale 1ns/1ps
module tb_hdmi_stats_osd;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,vs=0,de=0;
    wire [23:0] a,b;
    wire av,ad,bv,bd;
    ui_osd #(.MENU_CHINESE(0),.PIXEL_CLOCK_HZ(1000)) ascii_osd(.I_mipi_clk(clk),.I_mipi_frame_start(1'b0),.I_camera_display({7'd127,16'h2000}),
        .I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(1'b0),.I_de(de),.I_data(24'h526879),
        .I_menu_enable(1'b0),.I_edit_enable(1'b0),.I_info_enable(1'b0),.I_menu_index(3'd0),
        .I_picture_page(1'b0),.I_picture_ctrl(16'h1050),.I_record_status(32'd0),
        .I_exposure(16'd5990),.I_gain(16'd80),.I_servo_pan_us(16'd1500),.I_servo_tilt_us(16'd1500),
        .I_rtc_hours(8'h12),.I_rtc_minutes(8'h34),.I_rtc_seconds(8'h56),
        .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),.O_data(a),.O_vsync(av),.O_de(ad));
    ui_osd #(.MENU_CHINESE(1),.PIXEL_CLOCK_HZ(1000)) chinese_osd(.I_mipi_clk(clk),.I_mipi_frame_start(1'b0),.I_camera_display({7'd127,16'h2000}),
        .I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(1'b0),.I_de(de),.I_data(24'h526879),
        .I_menu_enable(1'b0),.I_edit_enable(1'b0),.I_info_enable(1'b0),.I_menu_index(3'd0),
        .I_picture_page(1'b0),.I_picture_ctrl(16'h1050),.I_record_status(32'd0),
        .I_exposure(16'd5990),.I_gain(16'd80),.I_servo_pan_us(16'd1500),.I_servo_tilt_us(16'd1500),
        .I_rtc_hours(8'h12),.I_rtc_minutes(8'h34),.I_rtc_seconds(8'h56),
        .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),.O_data(b),.O_vsync(bv),.O_de(bd));
    reg [23:0] old_pixel=0;
    reg old_de=0,old_vs=0;
    task tick;
        begin
            @(posedge clk);#1;
            if({bv,bd,b}!=={old_vs,old_de,old_pixel}) $fatal(1,"Chinese pipeline alignment");
            if({av,ad}!=={vs,de}) $fatal(1,"ASCII alignment");
            old_pixel=a;old_de=ad;old_vs=av;
            @(negedge clk);
        end
    endtask
    integer i,px,py,checked=0;
    initial begin
        repeat(2) @(negedge clk);rst=1;
        for(i=0;i<1000;i=i+1) begin vs=(i==99 || i==199 || i==299);tick();end
        vs=1;tick();vs=0;tick(); // Frame edges must no longer create a statistics panel.
        for(py=0;py<192;py=py+1) begin
            de=1;
            for(px=0;px<1920;px=px+1) begin
                tick();
                if(!(px>=818 && px<1102 && py>=16 && py<60) && a!==24'h526879)
                    $fatal(1,"Unexpected overlay at %d,%d",px,py);
                if(px>=1440 && px<1904 && py>=16 && py<168) begin
                    if(a!==24'h526879) $fatal(1,"Removed FPS/frame panel is not transparent");
                    checked=checked+1;
                end
                if(px==818 && py==16 && a!==24'h309060) $fatal(1,"RTC border removed");
            end
            de=0;tick();tick();
        end
        if(checked!=464*152) $fatal(1,"Missing statistics-panel coverage");
        $display("PASS no FPS/frame overlay: %0d restored video pixels, RTC preserved, ASCII/Chinese pipeline alignment",checked);$finish;
    end
endmodule
