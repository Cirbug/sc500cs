`timescale 1ns/1ps
module tb_touch_focus_osd;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,vs=0,de=0;reg [31:0] roi=0;
 wire ovs,ohs,ode;wire [23:0] rgb;
 integer sx=0,sy=0,rx=880,ry=480,checked=0;
 reg expected_check=0,next_check,old_check;
 reg [23:0] expected_data,next_data,old_data;
 ui_osd dut(.I_mipi_clk(clk),.I_mipi_frame_start(1'b0),.I_camera_display({7'd127,16'h2000}),.I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(1'b0),
   .I_de(de),.I_data(24'h2468ac),.I_focus_roi(roi),.I_menu_enable(1'b0),
   .I_edit_enable(1'b0),.I_info_enable(1'b0),.I_show_info(1'b1),.I_menu_index(3'd0),
   .I_record_status(32'd0),.I_picture_page(1'b0),.I_mode_page(1'b0),
   .I_image_step(3'd2),.I_picture_ctrl(16'h108c),
   .I_exposure(16'd5990),.I_gain(16'd80),.I_servo_pan_us(16'd1500),.I_servo_tilt_us(16'd1500),
   .I_rtc_hours(8'd0),.I_rtc_minutes(8'd0),.I_rtc_seconds(8'd0),
   .I_rtc_valid(1'b0),.I_rtc_error(1'b0),.I_rtc_osf(1'b1),
   .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_data(rgb));
 always @(posedge clk) if(rst) begin
   next_check=de && sx>=rx-2 && sx<rx+162 && sy>=ry-2 && sy<ry+122;
   next_data=(sx>=rx && sx<rx+160 && sy>=ry && sy<ry+120 &&
     (sx<rx+2 || sx>=rx+158 || sy<ry+2 || sy>=ry+118))?24'h40ff80:24'h2468ac;
   old_check=expected_check;old_data=expected_data;
   expected_check=next_check;expected_data=next_data;
   #1;
   if(old_check) begin
     if(!ode || rgb!==old_data) $fatal(1,"ROI OSD pixel mismatch got=%h expected=%h",rgb,old_data);
     checked=checked+1;
   end
 end
 task draw_frame;
 integer x,y;
 begin
   @(negedge clk);vs=1;de=0;
   @(negedge clk);vs=0;
   for(y=0;y<1080;y=y+1) begin
     for(x=0;x<1920;x=x+1) begin
       @(negedge clk);de=1;sx=x;sy=y;
     end
     @(negedge clk);de=0;
   end
   repeat(3) @(negedge clk);
 end endtask
 initial begin
   repeat(4) @(negedge clk);rst=1;
   roi=32'h81e00370;draw_frame();
   rx=1760;ry=960;roi=32'h83c006e0;draw_frame();
   if(checked!=164*124+162*122) $fatal(1,"Wrong checked area %d",checked);
   $display("PASS ROI OSD %0d pixels: exact 160x120 frame, 2px stroke, transparent interior, bottom-right bounds and video latency",checked);
   $finish;
 end
endmodule
