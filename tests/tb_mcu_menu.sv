`timescale 1ns/1ps
module tb_mcu_menu;
    reg clk=0,apb=0;always #7 clk=~clk;always #11 apb=~apb;
    reg rst=0,vs=0,hs=0,de=0,sel=0,en=0,wr=0;
    reg [7:0] addr=0;reg [31:0] wd=0;reg [3:0] strb=15;
    wire [31:0] rd;
    reg menu=1,page=0,modes=0,edit=0;
    reg [2:0] selection=0,image_step=4;
    reg [31:0] rec=0;
    reg [15:0] picture=16'h108c;
    wire ov,oh,od,rv,rh,rdv;wire [23:0] rgb,ref_rgb;
    ui_osd #(.MCU_MENU(1),.RESULT_CHINESE(1)) dut(
        .I_apb_clk(apb),.I_apb_rst_n(rst),.I_menu_sel(sel),.I_menu_penable(en),.I_menu_pwrite(wr),
        .I_menu_paddr(addr),.I_menu_pwdata(wd),.I_menu_pstrobe(strb),.O_menu_prdata(rd),
        .I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(24'h526879),
        .I_menu_enable(menu),.I_edit_enable(edit),.I_info_enable(1'b0),.I_menu_index(selection),
        .I_picture_page(page),.I_mode_page(modes),.I_record_status(rec),.I_picture_ctrl(picture),
        .I_camera_display({7'd127,16'h2000}),.I_gain(16'd80),.I_focus_roi(32'd0),.I_image_step(image_step),
        .I_image_effect(3'd4),.I_shape_valid(1'b1),.I_shape_type(3'd3),
        .I_shape_x0(12'd1000),.I_shape_y0(12'd200),.I_shape_y1(12'd400),
        .I_rtc_hours(8'h12),.I_rtc_minutes(8'h34),.I_rtc_seconds(8'h56),
        .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),
        .I_mipi_frames(32'h12345678),.I_mipi_fps(12'h030),.I_mipi_fps_valid(1'b1),
        .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(rgb));
    ui_osd #(.RESULT_CHINESE(1)) ref_osd(
        .I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(24'h526879),
        .I_menu_enable(menu),.I_edit_enable(edit),.I_info_enable(1'b0),.I_menu_index(selection),
        .I_picture_page(page),.I_mode_page(modes),.I_record_status(rec),.I_picture_ctrl(picture),
        .I_camera_display({7'd127,16'h2000}),.I_gain(16'd80),.I_focus_roi(32'd0),.I_image_step(image_step),
        .I_image_effect(3'd4),.I_shape_valid(1'b1),.I_shape_type(3'd3),
        .I_shape_x0(12'd1000),.I_shape_y0(12'd200),.I_shape_y1(12'd400),
        .I_rtc_hours(8'h12),.I_rtc_minutes(8'h34),.I_rtc_seconds(8'h56),
        .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),
        .I_mipi_frames(32'h12345678),.I_mipi_fps(12'h030),.I_mipi_fps_valid(1'b1),
        .O_vsync(rv),.O_hsync(rh),.O_de(rdv),.O_data(ref_rgb));
    task write_reg(input [7:0] a,input [31:0] d);
        @(negedge apb);sel=1;wr=1;addr=a;wd=d;en=0;
        @(negedge apb);en=1;
        @(negedge apb);sel=0;en=0;wr=0;
    endtask
    task frame;
        @(negedge clk);vs=1;repeat(6)@(negedge clk);vs=0;repeat(10)@(negedge clk);
    endtask
    reg [31:0] table_words[0:2303];
    string path;
    integer mode,i,px,py,checks=0;
    reg [23:0] delayed;
    reg [2:0] delayed_ctrl;
    task sample(input integer sx,input integer sy);
        begin
            @(negedge clk);px=sx;py=sy;de=1;hs=sy[0];
            repeat(4)@(negedge clk);
            if(rgb!==ref_rgb) $fatal(1,"mode=%0d pixel=%0d,%0d MCU=%h legacy=%h",mode,sx,sy,rgb,ref_rgb);
            checks++;
        end
    endtask
    initial begin
        if(!$value$plusargs("TABLE=%s",path))$fatal(1,"TABLE missing");
        $readmemh(path,table_words);
        #55;rst=1;repeat(10)@(negedge apb);
        addr=0;#1;if(rd!==32'h4d554931)$fatal(1,"ID");
        // An incomplete update cannot publish uninitialized RAM.
        write_reg(8,0);write_reg(12,32'hdeadbeef);write_reg(16,1);
        frame();addr=4;#1;if(rd!==4)$fatal(1,"short commit status %h",rd);
        force dut.x=px;force dut.y=py;force ref_osd.x=px;force ref_osd.y=py;
        for(mode=0;mode<9;mode++) begin
            menu=mode!=4;page=mode==1||mode==6;modes=mode==3||mode==8;
            selection=mode==8?3:0;edit=mode==5;image_step=mode==8?5:4;
            picture=mode==6?16'he8bf:16'h108c;
            rec=mode==7?32'h12344500:mode==2?32'h400:0;
            de=0;repeat(5)@(negedge clk);
            write_reg(8,0);
            for(i=0;i<256;i++)write_reg(12,table_words[mode*256+i]);
            write_reg(16,1);repeat(10)@(negedge apb);addr=4;#1;
            if(!rd[0])$fatal(1,"must remain busy until VSYNC");
            frame();repeat(6)@(negedge apb);addr=4;#1;if(rd!==2)$fatal(1,"commit status %h",rd);
            // Sample every glyph pixel plus background/border/slider edges.
            for(i=640;i<1080;i++) begin
                for(integer xx=20;xx<496;xx++)sample(xx,i);
            end
            sample(900,400);sample(820,18);sample(1450,25);
        end
        // The SAME ROM must also preserve dynamic Chinese effect/shape labels.
        image_step=3;repeat(6)@(negedge clk);
        for(i=404;i<448;i++)for(integer xx=998;xx<1074;xx++)sample(xx,i);
        image_step=2;repeat(6)@(negedge clk);
        for(i=22;i<66;i++)for(integer xx=198;xx<306;xx++)sample(xx,i);
        // Verify controls and background are all delayed by exactly one extra cycle.
        de=0;repeat(6)@(negedge clk);delayed=ref_rgb;delayed_ctrl={rv,rh,rdv};
        for(i=0;i<50;i++) begin
            de=i[0];hs=i[1];vs=i[2];@(posedge clk);#1;
            if({ov,oh,od}!==delayed_ctrl || rgb!==delayed)$fatal(1,"video pipeline alignment");
            delayed=ref_rgb;delayed_ctrl={rv,rh,rdv};@(negedge clk);
        end
        $display("PASS MCU menu pixel equivalence %0d samples; atomic publication, pipeline alignment",checks);
        $finish;
    end
endmodule
