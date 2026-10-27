`timescale 1ns/1ps
module tb_camera30_osd;
 reg clk=0;always #5 clk=~clk;
 reg [15:0] exposure=0;reg [6:0] bar=0;
 reg rst=0,vs=0,de=0;reg [31:0] roi=0;
 wire ovs,ohs,ode;wire [23:0] rgb;
 integer sx=0,sy=0,rx=880,ry=480,checked=0;
 reg expected_check=0,next_check,old_check;
 reg [23:0] expected_data,next_data,old_data;
 ui_osd dut(.I_mipi_clk(clk),.I_mipi_frame_start(1'b0),.I_camera_display({bar,16'h2000}),.I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(1'b0),
   .I_de(de),.I_data(24'h2468ac),.I_focus_roi(roi),.I_menu_enable(1'b0),
   .I_edit_enable(1'b0),.I_info_enable(1'b0),.I_show_info(1'b1),.I_menu_index(3'd0),
   .I_record_status(32'd0),.I_picture_page(1'b0),.I_mode_page(1'b0),
   .I_image_step(3'd2),.I_picture_ctrl(16'h108c),
   .I_exposure(exposure),.I_gain(16'd80),.I_servo_pan_us(16'd1500),.I_servo_tilt_us(16'd1500),
   .I_rtc_hours(8'd0),.I_rtc_minutes(8'd0),.I_rtc_seconds(8'd0),
   .I_rtc_valid(1'b0),.I_rtc_error(1'b0),.I_rtc_osf(1'b1),
   .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_data(rgb));
 integer value,previous=0,expected;
 initial begin
   repeat(4) @(negedge clk);rst=1;
   for(value=0;value<=6000;value=value+1) begin
     exposure=value;bar=value>=3990 ? 127 : ((value>>5)+(value>>10));vs=1;
     repeat(2) @(negedge clk);
     expected=value>=3990 ? 127 : ((value>>5)+(value>>10));
     if(dut.exposure_bar_width!==expected || dut.exposure_bar_width<previous || dut.exposure_bar_width>127)
       $fatal(1,"exposure bar %d -> %d expected %d",value,dut.exposure_bar_width,expected);
     previous=dut.exposure_bar_width;
     vs=0;repeat(2) @(negedge clk);
   end
   $display("PASS MCU supplied OSD exposure bar: 0..6000, monotonic, bounded, saturates at 3990");$finish;
 end
endmodule
