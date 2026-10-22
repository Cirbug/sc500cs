`timescale 1ns/1ps
module tb_panel_ui;
    reg clk=0,apb=0;always #7 clk=~clk;always #11 apb=~apb;
    reg rst=0,vs=0,de=0,sel=0,en=0,wr=0,detail=0;
    reg [7:0] addr=0;reg [31:0] wd=0;
    wire [31:0] rd;wire ov,oh,od;wire [23:0] rgb;
    ui_osd #(.MCU_MENU(1)) dut(
        .I_apb_clk(apb),.I_apb_rst_n(rst),.I_menu_sel(sel),.I_menu_penable(en),.I_menu_pwrite(wr),
        .I_menu_paddr(addr),.I_menu_pwdata(wd),.I_menu_pstrobe(4'hf),.O_menu_prdata(rd),
        .I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(1'b0),.I_de(de),.I_data(24'h526879),
        .I_menu_enable(1'b1),.I_edit_enable(1'b0),.I_info_enable(detail),.I_menu_index(3'd0),
        .I_picture_page(1'b0),.I_mode_page(1'b0),.I_record_status(32'd0),.I_picture_ctrl(16'h108c),
        .I_camera_display({7'd127,16'h2000}),.I_gain(16'd80),.I_focus_roi(32'd0),.I_image_step(3'd2),
        .I_image_effect(3'd0),.I_shape_valid(1'b0),.I_shape_type(3'd0),
        .I_shape_x0(12'd0),.I_shape_y0(12'd0),.I_shape_y1(12'd0),
        .I_rtc_hours(8'h14),.I_rtc_minutes(8'h32),.I_rtc_seconds(8'h08),
        .I_rtc_year(8'h26),.I_rtc_month(8'h10),.I_rtc_date(8'h18),
        .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),
        .I_mipi_frames(32'h12345678),.I_mipi_fps(12'h030),.I_mipi_fps_valid(1'b1),
        .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(rgb));
    reg [31:0] words[0:1791],font[0:4095];
    string tables,fonts;
    integer px=0,py=0,page,r,c,gx,gy,checks=0;
    reg [31:0] desc,bits;
    reg [23:0] background,foreground,expected;
    task write_reg(input [7:0] a,input [31:0] d);
        @(negedge apb);sel=1;wr=1;addr=a;wd=d;en=0;
        @(negedge apb);en=1;
        @(negedge apb);sel=0;en=0;wr=0;
    endtask
    task frame;
        @(negedge clk);vs=1;repeat(6)@(negedge clk);vs=0;repeat(10)@(negedge clk);
    endtask
    task sample(input integer sx,input integer sy,input [23:0] want);
        @(negedge clk);px=sx;py=sy;de=1;
        repeat(4)@(negedge clk);
        if(rgb!==want)$fatal(1,"page=%0d pixel=%0d,%0d got=%h expected=%h",page,sx,sy,rgb,want);
        checks++;
    endtask
    initial begin
        if(!$value$plusargs("TABLE=%s",tables) || !$value$plusargs("FONT=%s",fonts))$fatal(1,"paths missing");
        $readmemh(tables,words);$readmemh(fonts,font);
        #55;rst=1;repeat(10)@(negedge apb);
        force dut.x=px;force dut.y=py;
        for(page=0;page<7;page++) begin
            write_reg(8,0);
            for(integer i=0;i<256;i++)write_reg(12,words[page*256+i]);
            write_reg(16,1);repeat(8)@(negedge apb);frame();
            sample(24,644,24'h304652);
            sample(33,700,24'h50d8c0);
            sample(40,700,24'h395264);
            sample(24,1016,24'h50d8c0);
            // Independent 1-bit font source and MCU table exercise every Chinese pixel.
            for(r=0;r<9;r++)for(c=0;c<12;c++) begin
                desc=words[page*256+r*16+c];
                if(!desc[8] && !desc[14])begin
                    background=desc[13:12]==1?24'h395264:desc[13:12]==2?24'h59544c:24'h31404c;
                    foreground=desc[11:9]==0?24'he8edf2:24'h50d8c0;
                    for(gy=0;gy<32;gy++)begin
                        bits=font[desc[6:0]*32+gy];
                        for(gx=0;gx<32;gx++)begin
                            expected=bits[31-gx]?foreground:background;
                            sample((c<8?44+c*32:330+(c-8)*32)+gx,(r==0?658:694+(r-1)*36)+gy,expected);
                        end
                    end
                end
            end
            if(page==2)begin
                sample(330,720,24'h50d8c0);sample(457,720,24'h50d8c0);
                sample(393,756,24'h50d8c0);sample(394,756,24'h263b48);
            end
            // Simultaneous numeric value and bar: digit 3 at first exposure cell.
            if(page==2)begin
                sample(340,696,24'h50d8c0); // '3' top left stroke, small 2x glyph
                sample(340,711,24'h395264); // gap between number and bar
            end
            if(page==1)begin
                // AUTO uses the existing large ASCII font, not a new ROM.
                // Top glyph row: A=01110, U=10001, T=11111, O=01110.
                sample(330,949,24'h31404c);sample(334,949,24'h50d8c0);
                sample(362,949,24'h50d8c0);sample(366,949,24'h31404c);
                sample(394,949,24'h50d8c0);sample(402,949,24'h50d8c0);
                sample(426,949,24'h31404c);sample(430,949,24'h50d8c0);
            end
            sample(500,700,24'h526879); // No DDR/camera pixels changed outside UI.
        end
        sample(1440,96,24'h526879); // Compact FPS: no frame-count panel here.
        detail=1;sample(1440,96,24'h526879); // Wait until VSYNC.
        frame();sample(1440,96,24'h304652);
        detail=0;frame();sample(1440,96,24'h526879);
        $display("PASS panel theme/shared glyphs %0d samples, sliders, compact/detail frame latch and passthrough",checks);
        $finish;
    end
endmodule
