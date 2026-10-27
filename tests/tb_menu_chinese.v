`timescale 1ns/1ps
// Raster-level test: independent font-row reference, all menu labels/states,
// numeric/RTC comparison with legacy OSD, full video/control delay alignment.
module tb_menu_chinese #(parameter START_MODE=0, END_MODE=9);
    reg clk=0; always #5 clk=~clk;
    reg rst=0, vs=0, hs=0, de=0, menu=1, page=0;
    reg [31:0] rec=0;
    reg [15:0] picture=16'h108c;
    reg [2:0] selection=0;
    reg modes=0;
    wire ov,oh,od,ev,eh,ed;
    wire [23:0] pixel, english;
    ui_osd dut(.I_mipi_clk(clk),.I_mipi_frame_start(1'b0),.I_camera_display({7'd127,16'h2000}),.I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(hs),.I_de(de),
        .I_record_status(rec),.I_data(24'h526879),.I_menu_enable(menu),.I_edit_enable(1'b0),
        .I_info_enable(1'b0),.I_show_info(1'b1),.I_menu_index(selection),.I_picture_page(page),.I_mode_page(modes),.I_image_step(3'd4),
        .I_focus_roi(32'd0),.I_picture_ctrl(picture),.I_exposure(16'd5990),.I_gain(16'd80),
        .I_servo_pan_us(16'd1500),.I_servo_tilt_us(16'd1500),
        .I_rtc_hours(8'h12),.I_rtc_minutes(8'h34),.I_rtc_seconds(8'h56),
        .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),
        .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(pixel));
    ui_osd #(.MENU_CHINESE(0)) reference_osd(.I_mipi_clk(clk),.I_mipi_frame_start(1'b0),.I_camera_display({7'd127,16'h2000}),
        .I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(hs),.I_de(de),
        .I_record_status(rec),.I_data(24'h526879),.I_menu_enable(menu),.I_edit_enable(1'b0),
        .I_info_enable(1'b0),.I_show_info(1'b1),.I_menu_index(selection),.I_picture_page(page),.I_mode_page(modes),.I_image_step(3'd4),
        .I_focus_roi(32'd0),.I_picture_ctrl(picture),.I_exposure(16'd5990),.I_gain(16'd80),
        .I_servo_pan_us(16'd1500),.I_servo_tilt_us(16'd1500),
        .I_rtc_hours(8'h12),.I_rtc_minutes(8'h34),.I_rtc_seconds(8'h56),
        .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),
        .O_vsync(ev),.O_hsync(eh),.O_de(ed),.O_data(english));
    reg [31:0] rows[0:4095];
    reg [7:0] labels[0:511], values[0:55];
    reg prev_vs=0,prev_hs=0,prev_de=0;
    reg [23:0] prev_english=0,expected,color;
    integer px,py,qx=0,qy=0,mode,fd=0,line_id,local_y,cell_id,glyph_id,local_x,kind;
    integer tested=0;
    reg check_cn;
    task tick;
        begin
            @(posedge clk); #1;
            if({ov,oh,od}!=={prev_vs,prev_hs,prev_de}) $fatal(1,"Chinese control latency");
            if(!prev_de && pixel!==0) $fatal(1,"Chinese blanking pixel");
            if(prev_de) begin
                expected=prev_english;
                check_cn=0; glyph_id=0; local_x=0; local_y=0; color=24'hffffff;
                // The whole label strip must be free of the former ASCII text.
                if(menu && qx>=44 && qx<300 && qy>=658 && qy<(page||rec[10]||modes?942:978)) begin
                    check_cn=1; line_id=(qy-658)/36; local_y=(qy-658)%36;
                    local_x=(qx-44)%32; cell_id=(qx-44)/32;
                    if(local_y<32) glyph_id=labels[(modes?384:rec[10]?256:page?128:0)+line_id*8+cell_id];
                    /* 2026-10-27：第一行改成黄色，参考模型跟着改。 */
                    if(line_id==0) color=24'hfff200;
                    else if(modes && line_id==3) color=24'h80e0c0;
                end
                if(menu && (page || rec[10] || modes) && qx>=330 && qx<458 && qy>=658 && qy<942) begin
                    line_id=(qy-658)/36; local_y=(qy-658)%36;
                    if(modes ? line_id==0 : rec[10] ? (line_id==0 || line_id>=6) : (line_id==0 || line_id==2 || line_id>=5)) begin
                        check_cn=1; local_x=(qx-330)%32; cell_id=(qx-330)/32;
                        color=(line_id==0) ? 24'hfff200 : 24'h80e0c0;   /* 首行黄色 */
                        kind=0;
                        case(line_id)
                            0:kind=0;
                            2:kind=picture[6]?2:1;
                            5:case(picture[13:12]) 0:kind=3; 1:kind=4; 2:kind=5; 3:kind=1; endcase
                            6:case(picture[15:14]) 0:kind=1; 1:kind=6; 2:kind=7; 3:kind=8; endcase
                            7:kind=9;
                        endcase
                        if(rec[10]) kind=line_id==6?(rec[7:0]!=0?12:rec[9]?11:rec[8]?13:10):0;
                        if(local_y<32) glyph_id=values[kind*4+cell_id];
                    end
                end
                if(check_cn) begin
                    expected=24'h101820;
                    if(qy>=692 && qy<980 && ((qy-692)/36)==selection) expected=24'h205080;
                    if(glyph_id && local_y<32 && rows[glyph_id*32+local_y][31-local_x]) expected=color;
                    tested=tested+1;
                end
                // Menu button: verify transparent padding as well as both glyphs.
                if(qx>=24 && qx<220 && qy>=1016 && qy<1076) begin
                    expected=24'h183050;
                    if(qx<28 || qx>=216 || qy<1020 || qy>=1072) expected=24'h3090d0;
                    if(qx>=90 && qx<154 && qy>=1030 && qy<1062) begin
                        glyph_id=labels[(qx-90)/32];
                        if(rows[glyph_id*32+qy-1030][31-((qx-90)%32)]) expected=24'hffffff;
                    end
                end
                if(pixel!==expected) $fatal(1,"CN raster mode=%d at %d,%d got=%h expected=%h",mode,qx,qy,pixel,expected);
                if(fd && qx<512 && qy>=636)
                    $fwrite(fd,"%d %d %d\n",pixel[23:16],pixel[15:8],pixel[7:0]);
            end
            prev_vs=vs; prev_hs=hs; prev_de=de; prev_english=english;
            qx=px; qy=py;
            @(negedge clk);
        end
    endtask
    initial begin
        $readmemh("assets/menu_font/rows.hex",rows);
        $readmemh("assets/menu_font/labels.hex",labels);
        $readmemh("assets/menu_font/values.hex",values);
        repeat(3) @(negedge clk); rst=1;
        for(mode=START_MODE;mode<END_MODE;mode=mode+1) begin
            menu=(mode!=5); page=(mode>0 && mode<5);
            modes=(mode==8);
            rec=mode==6?32'h01234500:mode==7?32'h01234621:0; selection=page?2:0;
            picture=16'h108c;
            if(mode==6) fd=$fopen("build/sd_recorder_menu.ppm","w");
            if(mode>=1 && mode<=4) begin
                picture[13:12]=mode-1; picture[15:14]=mode-1; picture[6]=mode[0];
            end
            if(mode==0) fd=$fopen("build/menu_chinese_main.ppm","w");
            if(mode==8) begin fd=$fopen("build/menu_modes.ppm","w");selection=2;end
            if(mode==2) fd=$fopen("build/menu_chinese_picture.ppm","w");
            if(fd) $fwrite(fd,"P3\n512 444\n255\n");
            repeat(5) tick; // settle the APB-to-pixel status synchronizer
            vs=1; tick; vs=0; tick;
            for(py=0;py<1080;py=py+1) begin
                de=1;
                for(px=0;px<1920;px=px+1) tick;
                de=0; hs=1; tick; hs=0; tick;
            end
            tick;
            if(fd) $fclose(fd); fd=0;
        end
        $display("PASS Chinese glyph raster, all states, padding, menu hide, ASCII values/clock, video and sync alignment (%d pixels)",tested);
        $finish;
    end
endmodule
