`timescale 1ns/1ps
module tb_hdmi_stats_osd;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,vs=0,de=0;
    reg [31:0] cam_frames=32'h00001234;
    reg [11:0] cam_fps=12'h030;
    wire [23:0] a,b;
    wire av,ad,bv,bd;
    ui_osd #(.MENU_CHINESE(0),.PIXEL_CLOCK_HZ(1000)) ascii_osd(
        .I_camera_display({7'd127,16'h2000}),.I_mipi_frames(cam_frames),.I_mipi_fps(cam_fps),.I_mipi_fps_valid(1'b1),
        .I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(1'b0),.I_de(de),.I_data(24'h526879),
        .I_menu_enable(1'b0),.I_edit_enable(1'b0),.I_info_enable(1'b0),.I_menu_index(3'd0),
        .I_picture_page(1'b0),.I_picture_ctrl(16'h1050),.I_record_status(32'd0),
        .I_exposure(16'd5990),.I_gain(16'd80),.I_servo_pan_us(16'd1500),.I_servo_tilt_us(16'd1500),
        .I_rtc_hours(8'h12),.I_rtc_minutes(8'h34),.I_rtc_seconds(8'h56),
        .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),.O_data(a),.O_vsync(av),.O_de(ad));
    ui_osd #(.MENU_CHINESE(1),.PIXEL_CLOCK_HZ(1000)) chinese_osd(
        .I_camera_display({7'd127,16'h2000}),.I_mipi_frames(cam_frames),.I_mipi_fps(cam_fps),.I_mipi_fps_valid(1'b1),
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
    function [4:0] top_row;
        input [7:0] c;
        begin
            case(c)
                "H","M":top_row=5'b10001;
                "D","P","R":top_row=5'b11110;
                "I":top_row=5'b11111;
                "F","E":top_row=5'b11111;
                "S":top_row=5'b01111;
                "A","0":top_row=5'b01110;
                "3":top_row=5'b11110;
                "1":top_row=5'b00100;
                "2":top_row=5'b01110;
                "4":top_row=5'b00010;
                default:top_row=0;
            endcase
        end
    endfunction
    integer i,px,py,fd,index,col;
    reg [111:0] line;
    reg [4:0] bits;
    reg [23:0] expected;
    initial begin
        repeat(2) @(negedge clk);rst=1;
        for(i=0;i<1000;i=i+1) begin vs=(i==99 || i==199 || i==299);tick();end
        vs=1;tick();vs=0;tick(); // fourth frame, displays prior window = 3 FPS
        cam_frames=32'h00005678;cam_fps=12'h020; // must remain frozen until next VS
        fd=$fopen("build/hdmi_stats_preview.ppm","w");
        $fwrite(fd,"P3\n1920 184\n255\n");
        for(py=0;py<184;py=py+1) begin
            de=1;
            for(px=0;px<1920;px=px+1) begin
                tick();
                $fwrite(fd,"%d %d %d\n",a[23:16],a[15:8],a[7:0]);
                if(!((px>=818 && px<1102 && py>=16 && py<60) ||
                     (px>=1440 && px<1904 && py>=16 && py<168)) && a!==24'h526879)
                    $fatal(1,"Overlay outside panels");
                if((py==24 || py==60 || py==96 || py==132) && px>=1448 && px<1896) begin
                    line=py==24 ? "HDMI FPS 003  " : py==60 ? "FRAME 00000004" :
                         py==96 ? "MIPI FPS 030  " : "FRAME 00001234";
                    index=(px-1448)/32;col=((px-1448)%32)/4;
                    bits=top_row(line[111-index*8 -:8]);
                    expected=(col<5 && (bits & (5'b10000>>col)))?
                             (py>=96 ? 24'h80ffb0 : 24'h80e0ff):24'h101820;
                    if(a!==expected) $fatal(1,"Stats glyph at %d,%d got=%h expected=%h",px,py,a,expected);
                end
                if(ascii_osd.fps_frame!==12'h003) $fatal(1,"FPS changed during active frame");
                if(ascii_osd.mipi_fps_frame!==12'h030 || ascii_osd.mipi_frames_frame!==32'h00001234)
                    $fatal(1,"MIPI digits changed during active frame");
            end
            de=0;tick();tick();
        end
        $fclose(fd);
        $display("PASS centered clock, independent HDMI/MIPI FPS/frame digits, bounds, frame freeze, Chinese pipeline alignment");$finish;
    end
endmodule
