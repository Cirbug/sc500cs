`timescale 1ns/1ps
module tb_red_track_label;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,vs=0,hs=0,de=1,valid=1,menu=0;
    reg [2:0] step=5;
    reg [11:0] px=0,py=0,x0=1000,y0=300,x1=1300,y1=500,cx=1150,cy=400;
    reg xneg=0,yneg=0;
    reg [15:0] xb=16'h0190,yb=16'h0140;
    wire hit;wire [23:0] box_color;
    red_tracking_osd box_only(.I_clk(clk),.I_rst_n(rst),.I_enable(step==5),.I_de(de),
        .I_new_result(1'b0),.I_valid(valid),.I_x(px),.I_y(py),
        .I_x0(x0),.I_y0(y0),.I_x1(x1),.I_y1(y1),.I_cx(cx),.I_cy(cy),
        .I_state(2'd1),.I_dir_x(2'd0),.I_dir_y(2'd0),.I_level_x(2'd0),.I_level_y(2'd0),
        .I_error_x(13'sd0),.I_error_y(13'sd0),.I_area_percent(7'd1),.O_hit(hit),.O_color(box_color));
    wire [23:0] video=hit?box_color:24'h527891;
    wire [23:0] data_out[0:3];wire [3:0] ovs,ohs,ode;
    genvar n;
    generate for(n=0;n<4;n=n+1) begin:g
        ui_osd #(.RESULT_CHINESE(n%2),.MCU_MENU(n/2)) dut(
            .I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(video),
            .I_apb_clk(clk),.I_apb_rst_n(rst),.I_menu_sel(1'b0),.I_menu_penable(1'b0),.I_menu_pwrite(1'b0),
            .I_menu_paddr(8'd0),.I_menu_pstrobe(4'd0),.I_menu_pwdata(32'd0),
            .I_mipi_clk(clk),.I_mipi_frame_start(1'b0),.I_camera_display({7'd127,16'h2000}),
            .I_mipi_frames(32'd0),.I_mipi_fps(12'd0),.I_mipi_fps_valid(1'b0),
            .I_record_status(32'd0),.I_menu_enable(menu),.I_edit_enable(1'b0),.I_info_enable(1'b0),
            .I_menu_index(3'd0),.I_picture_page(1'b0),.I_mode_page(1'b0),.I_focus_roi(32'd0),
            .I_focus_roi_w(11'd0),.I_focus_roi_h(11'd0),   /* 0 = 默认 160x120 */
            .I_image_step(step),.I_image_effect(3'd0),.I_shape_valid(1'b0),.I_shape_type(3'd0),
            .I_shape_x0(12'd0),.I_shape_y0(12'd0),.I_shape_y1(12'd0),
            /* gege 8f21399 新增：颜色结果文字层与可变对焦窗口。悬空会成 X 并污染像素比对。 */             .I_color_valid(1'b0),.I_color_code(3'd0),             .I_color_x0(12'd0),.I_color_y0(12'd0),.I_color_y1(12'd0),
            .I_track_valid(valid),.I_track_x0(x0),.I_track_y0(y0),.I_track_y1(y1),
            .I_track_x_negative(xneg),.I_track_y_negative(yneg),.I_track_x_bcd(xb),.I_track_y_bcd(yb),
            .I_picture_ctrl(16'h108c),.I_exposure(16'd3990),.I_gain(16'd80),
            .I_servo_pan_us(16'd1500),.I_servo_tilt_us(16'd1500),
            .I_rtc_hours(8'h12),.I_rtc_minutes(8'h34),.I_rtc_seconds(8'h56),
            .I_rtc_year(8'h26),.I_rtc_month(8'h10),.I_rtc_date(8'h20),
            .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),
            .I_latency_bcd(16'd0),.I_camera_period_bcd(16'd0),.I_repeat_bcd(16'd0),
            .I_latency_valid(1'b0),.I_camera_period_valid(1'b0),
            .O_menu_prdata(),.O_vsync(ovs[n]),.O_hsync(ohs[n]),.O_de(ode[n]),.O_data(data_out[n]));
        // Probe actual rendered pixels while retaining both real output pipelines.
        initial begin force dut.x=px;force dut.y=py;end
    end endgenerate
    reg [31:0] rows[0:4095];
    reg [7:0] labels[0:511];
    reg [34:0] patterns[0:127];
    integer tx,ty,dx,dy,k,cell_id,r,c,id,i,j,scenario,checked=0,fd=0;
    reg covered;reg [23:0] expected;reg [7:0] ch;
    string outdir,path;
    task tick;@(posedge clk);#1;@(negedge clk);endtask
    task probe(input integer xx,yy);
        px=xx;py=yy;repeat(5) tick;
        for(k=0;k<2;k=k+1) begin
            if({ovs[k*2],ohs[k*2],ode[k*2]}!=={ovs[k*2+1],ohs[k*2+1],ode[k*2+1]})
                $fatal(1,"Changed output sync");
            expected=data_out[k*2];
            covered=(menu && xx>=24 && xx<492 && yy>=644 && yy<1004) ||
                (xx>=24 && xx<220 && yy>=1016 && yy<1076) ||
                (xx>=236 && xx<260 && yy>=1034 && yy<1058) ||
                (xx>=818 && xx<1102 && yy>=16 && yy<96) ||
                (xx>=1440 && xx<1904 && yy>=16 && yy<(k==0?276:96));
            if(valid && step==5 && de && !covered && xx>=tx && xx<tx+304 && yy>=ty && yy<ty+72) begin
                expected=24'h101820;
                dx=xx-tx-4;dy=yy-ty-20;
                if(dx>=0 && dx<64 && dy>=0 && dy<32) begin
                    id=labels[416+dx/32]; // independently exported "red", "color"
                    if(rows[id*32+dy][31-dx%32]) expected=24'hff4040;
                end
                dx=xx-tx-76;dy=yy-ty-6;
                if(dx>=0 && dx<224 && dy>=0 && dy<60) begin
                    cell_id=dx/32;r=(dy%32)/4;c=(dx%32)/4;
                    case(cell_id)
                        0:ch=dy>=32?"Y":"X";
                        1:ch=":";
                        2:ch=(dy>=32?yneg:xneg)?"-":"+";
                        default:ch="0"+(((dy>=32?yb:xb)>>((6-cell_id)*4))&15);
                    endcase
                    if(r<7 && c<5 && patterns[ch][34-r*5-c]) expected=24'hff4040;
                end
            end
            if(data_out[k*2+1]!==expected)
                $fatal(1,"Label scenario=%0d MCU=%0d xy=%0d,%0d actual=%h expected=%h",scenario,k,xx,yy,data_out[k*2+1],expected);
            if(!de && data_out[k*2+1]!==0) $fatal(1,"Blanking not black");
            checked=checked+1;
        end
        if(fd) $fwrite(fd,"%0d %0d %0d\n",data_out[3][23:16],data_out[3][15:8],data_out[3][7:0]);
    endtask
    initial begin
        $readmemh("assets/menu_font/rows.hex",rows);
        $readmemh("assets/menu_font/labels.hex",labels);
        for(i=0;i<128;i=i+1) patterns[i]=0;
        patterns["X"]={5'b10001,5'b10001,5'b01010,5'b00100,5'b01010,5'b10001,5'b10001};
        patterns["Y"]={5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
        patterns[":"]={5'd0,5'd0,5'd4,5'd0,5'd4,5'd0,5'd0};
        patterns["+"]={5'd0,5'd4,5'd4,5'd31,5'd4,5'd4,5'd0};
        patterns["-"]={5'd0,5'd0,5'd0,5'd31,5'd0,5'd0,5'd0};
        patterns["0"]={5'd14,5'd17,5'd19,5'd21,5'd25,5'd17,5'd14};
        patterns["1"]={5'd4,5'd12,5'd4,5'd4,5'd4,5'd4,5'd14};
        patterns["2"]={5'd14,5'd17,5'd1,5'd2,5'd4,5'd8,5'd31};
        patterns["3"]={5'd30,5'd1,5'd1,5'd14,5'd1,5'd1,5'd30};
        patterns["4"]={5'd2,5'd6,5'd10,5'd18,5'd31,5'd2,5'd2};
        patterns["5"]={5'd31,5'd16,5'd16,5'd30,5'd1,5'd1,5'd30};
        patterns["6"]={5'd14,5'd16,5'd16,5'd30,5'd17,5'd17,5'd14};
        patterns["7"]={5'd31,5'd1,5'd2,5'd4,5'd8,5'd8,5'd8};
        patterns["8"]={5'd14,5'd17,5'd17,5'd14,5'd17,5'd17,5'd14};
        patterns["9"]={5'd14,5'd17,5'd17,5'd15,5'd1,5'd1,5'd14};
        if(!$value$plusargs("OUT_DIR=%s",outdir)) outdir="build";
        repeat(3) tick;rst=1;repeat(5) tick;
        for(scenario=0;scenario<9;scenario=scenario+1) begin
            valid=1;step=5;menu=0;de=1;
            x0=1000;y0=300;x1=1300;y1=500;cx=1150;cy=400;
            xb=16'h0190;yb=16'h0140;xneg=0;yneg=0;
            case(scenario)
                1:begin x0=1890;y0=1000;x1=1919;y1=1079;xb=16'h0959;yb=16'h0539;yneg=1;end
                2:begin x0=0;y0=0;x1=80;y1=1079;xb=16'h0960;yb=16'h0540;xneg=1;end
                3:begin xb=0;yb=0;end
                4:valid=0;
                5:step=4;
                6:begin menu=1;x0=40;y0=300;x1=300;y1=650;xneg=1;yneg=1;end
                7:begin x0=1500;y0=0;x1=1600;y1=60;end
                8:de=0;
            endcase
            tx=x0>1616?1616:x0;ty=y1<=962?y1+46:(y0>=118?y0-118:0);
            vs=1;repeat(5) tick;vs=0;repeat(5) tick;
            for(j=ty;j<ty+72;j=j+1)
                for(i=tx;i<tx+304;i=i+1) probe(i,j);
            probe(tx>0?tx-1:tx,ty);probe(tx+304,ty);probe(tx,ty+72);
            probe(960,540);probe(x0,y0);probe(cx,cy);
            if(scenario==0) begin
                path={outdir,"/red_track_label.ppm"};fd=$fopen(path,"w");
                if(!fd) $fatal(1,"Cannot create preview");
                $fwrite(fd,"P3\n480 320\n255\n");
                for(j=280;j<600;j=j+1)
                    for(i=980;i<1460;i=i+1) probe(i,j);
                $fclose(fd);fd=0;
            end
            $display("PASS red label scenario %0d",scenario);
        end
        $display("PASS red label: %0d pixels, Chinese/signs/digits, edge clamping, loss/mode/blanking, menu/clock/stats priority, both OSD pipelines",checked);
        $finish;
    end
endmodule
