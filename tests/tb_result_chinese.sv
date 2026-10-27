`timescale 1ns/1ps
// Raster checks use independent exported glyph rows and specified coordinates.
// The unannotated OSD is the reference outside the label, including menu/clock.
module tb_result_chinese;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,vs=0,hs=0,de=0,menu=0,valid=0;
    reg [2:0] step=2,effect=0,kind=0;
    reg [11:0] x0=600,y0=120,x1=820,y1=270;
    integer px=0,py=0,qx=0,qy=0,scenario,fd=0;
    reg [23:0] rgb=24'h527891;
    wire box_hit;wire [23:0] box_color;
    shape_osd_renderer #(.LABEL_ENABLE(0)) box_only(.I_de(de),.I_x(px[11:0]),.I_y(py[11:0]),
        .I_valid(valid && step==3),.I_type(kind),.I_x0(x0),.I_y0(y0),.I_x1(x1),.I_y1(y1),
        .O_hit(box_hit),.O_color(box_color));
    wire [23:0] video=box_hit?box_color:rgb;
    wire [23:0] data_out[0:1];wire [1:0] ovs,ohs,ode;
    genvar n;
    generate for(n=0;n<2;n=n+1) begin:g
        ui_osd #(.RESULT_CHINESE(n)) dut(.I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(video),
            .I_mipi_clk(clk),.I_mipi_frame_start(1'b0),.I_camera_display({7'd127,16'h2000}),
            .I_mipi_frames(32'h00001234),.I_mipi_fps(12'h015),.I_mipi_fps_valid(1'b1),
            .I_record_status(32'd0),.I_menu_enable(menu),.I_edit_enable(1'b0),.I_info_enable(1'b0),.I_show_info(1'b1),
            .I_menu_index(3'd0),.I_picture_page(1'b0),.I_mode_page(1'b0),.I_focus_roi(32'd0),
            .I_image_step(step),.I_image_effect(effect),.I_shape_valid(valid),.I_shape_type(kind),
            .I_shape_x0(x0),.I_shape_y0(y0),.I_shape_y1(y1),
            .I_picture_ctrl(16'h108c),.I_exposure(16'd3990),.I_gain(16'd80),
            .I_servo_pan_us(16'd1500),.I_servo_tilt_us(16'd1500),
            .I_rtc_hours(8'h12),.I_rtc_minutes(8'h34),.I_rtc_seconds(8'h56),
            .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),
            .O_vsync(ovs[n]),.O_hsync(ohs[n]),.O_de(ode[n]),.O_data(data_out[n]));
    end endgenerate
    reg [31:0] rows[0:4095];reg [7:0] effects[0:31],shapes[0:31];
    integer tx,ty,tw,dx,dy,glyph_id,count=0,ink=0,frame_ink;
    integer preview_x,preview_y,preview_w=240,preview_h=100;
    reg show_label,covered,was_de=0,was_vs=0,was_hs=0;
    reg [23:0] expected,color;
    string outdir,path;
    task tick;
        begin
            @(posedge clk);#1;
            if({ovs[1],ohs[1],ode[1]}!=={was_vs,was_hs,was_de}) $fatal(1,"Control latency changed");
            if({ovs[1],ohs[1],ode[1]}!=={ovs[0],ohs[0],ode[0]}) $fatal(1,"Reference latency differs");
            expected=data_out[0];
            if(was_de) begin
                covered=(menu && qx>=24 && qx<492 && qy>=644 && qy<1004) ||
                    (qx>=24 && qx<220 && qy>=1016 && qy<1076) ||
                    (qx>=236 && qx<260 && qy>=1034 && qy<1058) ||
                    (qx>=818 && qx<1102 && qy>=16 && qy<60) ||
                    (qx>=1440 && qx<1904 && qy>=16 && qy<168);
                if(show_label && !covered && qx>=tx && qx<tx+tw && qy>=ty && qy<ty+40) begin
                    expected=24'h101820;dx=qx-tx-4;dy=qy-ty-4;
                    if(dx>=0 && dx<tw-8 && dy>=0 && dy<32) begin
                        glyph_id=step==2?effects[effect*4+dx/32]:shapes[kind*4+dx/32];
                        if(rows[glyph_id*32+dy][31-(dx%32)]) begin
                            expected=color;ink=ink+1;frame_ink=frame_ink+1;
                        end
                    end
                end
                if(data_out[1]!==expected) $fatal(1,"Result scenario=%0d xy=%0d,%0d got=%h expected=%h",scenario,qx,qy,data_out[1],expected);
                count=count+1;
                if(fd && qx>=preview_x && qx<preview_x+preview_w && qy>=preview_y && qy<preview_y+preview_h)
                    $fwrite(fd,"%0d %0d %0d\n",data_out[1][23:16],data_out[1][15:8],data_out[1][7:0]);
            end else if(data_out[1]!==0) $fatal(1,"Nonzero blanking");
            // Disabling the old label must remove every English pixel outside
            // the geometric rectangle, without changing that rectangle.
            if(de && valid && step==3 && (px<x0 || px>x1 || py<y0 || py>y1) && box_hit)
                $fatal(1,"Old shape caption still present");
            was_de=de;was_vs=vs;was_hs=hs;qx=px;qy=py;
            @(negedge clk);
        end
    endtask
    initial begin
        $readmemh("assets/menu_font/rows.hex",rows);
        $readmemh("assets/menu_font/effects.hex",effects);$readmemh("assets/menu_font/shapes.hex",shapes);
        if(!$value$plusargs("OUT_DIR=%s",outdir)) outdir="build";
        repeat(3) @(negedge clk);rst=1;
        for(scenario=0;scenario<19;scenario=scenario+1) begin
            step=2;effect=0;kind=0;valid=0;menu=0;show_label=0;
            tx=200;ty=24;tw=72;color=24'hffffff;frame_ink=0;
            x0=600;y0=120;x1=820;y1=270;
            if(scenario>=1 && scenario<=5) begin
                effect=scenario;show_label=1;tw=scenario==5?136:(scenario>=3?104:72);
                rgb=scenario==1?24'h808080:scenario==2?24'had876e:scenario==3?24'hffffff:scenario==4?24'hbca783:24'h000000;
            end else if(scenario>=6 && scenario<=10) begin
                step=3;kind=scenario-5;valid=1;show_label=1;
            end else if(scenario==11) begin // lower-right triangle: shift left and above
                step=3;kind=4;valid=1;show_label=1;x0=1890;x1=1919;y0=1000;y1=1079;
            end else if(scenario==12) begin // menu overlaps an otherwise valid label
                step=3;kind=1;valid=1;show_label=1;menu=1;x0=40;x1=300;y0=300;y1=650;
            end else if(scenario==13) begin // same Y as menu rows, outside its X range
                step=3;kind=4;valid=1;show_label=1;menu=1;x0=700;x1=900;y0=300;y1=650;
            end else if(scenario==14) begin step=3;kind=1;valid=0;end
            else if(scenario==15) begin step=3;kind=0;valid=1;end
            else if(scenario==16) begin step=4;effect=5;kind=1;valid=1;end
            else if(scenario==17) begin // top-right label and frame bounds
                step=3;kind=5;valid=1;show_label=1;x0=1900;x1=1919;y0=0;y1=1079;
            end else if(scenario==18) begin // restored statistics own their pixels
                step=3;kind=1;valid=1;show_label=1;x0=1500;x1=1600;y0=0;y1=60;
            end
            if(step==3 && show_label) begin
                tw=kind==4?104:72;tx=x0>1920-tw?1920-tw:x0;
                ty=y1<=1034?y1+6:(y0>=44?y0-44:0);color=24'hfff200;rgb=24'h527891;
            end
            preview_x=tx>16?tx-16:0;if(preview_x+preview_w>1920) preview_x=1920-preview_w;
            preview_y=ty>40?ty-40:0;if(preview_y+preview_h>1080) preview_y=1080-preview_h;
            if(show_label) begin
                path=$sformatf("%s/result_%0d.ppm",outdir,scenario);fd=$fopen(path,"w");
                if(!fd) $fatal(1,"Cannot create preview %s",path);
                $fwrite(fd,"P3\n%0d %0d\n255\n",preview_w,preview_h);
            end
            repeat(5) tick;vs=1;tick;vs=0;tick;
            for(py=0;py<1080;py=py+1) begin
                de=1;for(px=0;px<1920;px=px+1) tick;
                de=0;hs=1;tick;hs=0;tick;
            end
            tick;if(fd) $fclose(fd);fd=0;
            if(show_label && scenario!=12 && scenario!=18 && frame_ink<100) $fatal(1,"Missing Chinese glyphs");
            if(scenario==18 && frame_ink!=0) $fatal(1,"Shape label overwrote statistics");
            $display("PASS result scenario %0d glyph pixels=%0d",scenario,frame_ink);
        end
        $display("PASS Chinese results: %0d raster pixels, %0d glyph pixels, all effects/types/edges/occlusion/hide/sync",count,ink);
        $finish;
    end
endmodule
