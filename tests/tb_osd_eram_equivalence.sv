`timescale 1ns/1ps
module tb_osd;
parameter DEBUG_TEST=0;
reg  I_clk=0;
reg  I_rst_n=0;
reg  I_video_vsync=0;
reg  I_video_hsync=0;
reg  I_video_de=0;
reg  I_video_user=0;
reg  I_video_last=0;
reg [3:0] I_debug_status=0;
reg [2:0] I_dbg_mode=0;
reg [2:0] I_dbg_step=0;
reg [2:0] I_dbg_effect=0;
reg  I_dbg_awb_off=0;
reg  I_recog_mode=0;
reg  I_logo_enable=0;
reg [1:0] I_motion_target=0;
reg [7:0] I_dbg_sat_pre=0;
reg [7:0] I_dbg_sat_post=0;
reg [7:0] I_dbg_mean_r=0;
reg [7:0] I_dbg_mean_g=0;
reg [7:0] I_dbg_mean_b=0;
reg [7:0] I_dbg_min_r=0;
reg [7:0] I_dbg_noise=0;
reg [7:0] I_dbg_mean_y=0;
reg  I_shape_valid=0;
reg [2:0] I_shape_type=0;
reg [11:0] I_shape_x0=0;
reg [11:0] I_shape_y0=0;
reg [11:0] I_shape_x1=0;
reg [11:0] I_shape_y1=0;
reg  I_motion_valid=0;
reg [15:0] I_motion_count=0;
reg [2:0] I_motion_tvalid=0;
reg [11:0] I_motion_x0_0=0;
reg [11:0] I_motion_y0_0=0;
reg [11:0] I_motion_x1_0=0;
reg [11:0] I_motion_y1_0=0;
reg [11:0] I_motion_x0_1=0;
reg [11:0] I_motion_y0_1=0;
reg [11:0] I_motion_x1_1=0;
reg [11:0] I_motion_y1_1=0;
reg [11:0] I_motion_x0_2=0;
reg [11:0] I_motion_y0_2=0;
reg [11:0] I_motion_x1_2=0;
reg [11:0] I_motion_y1_2=0;
reg  I_color_valid=0;
reg [2:0] I_color_code=0;
reg [15:0] I_color_count=0;
reg [11:0] I_color_x0=0;
reg [11:0] I_color_y0=0;
reg [11:0] I_color_x1=0;
reg [11:0] I_color_y1=0;
reg  I_track_new=0;
reg  I_track_valid=0;
reg [1:0] I_track_state=0;
reg [1:0] I_track_dx=0;
reg [1:0] I_track_dy=0;
reg [1:0] I_track_lx=0;
reg [1:0] I_track_ly=0;
reg [11:0] I_track_x0=0;
reg [11:0] I_track_y0=0;
reg [11:0] I_track_x1=0;
reg [11:0] I_track_y1=0;
reg [11:0] I_track_cx=0;
reg [11:0] I_track_cy=0;
reg signed [12:0] I_track_ex=0;
reg signed [12:0] I_track_ey=0;
reg [6:0] I_track_area=0;
reg [23:0] I_video_rd_data=0;
always #5 I_clk=~I_clk;
wire  ref_off_O_video_rd_en;
wire  ref_off_O_hdmi_vsync;
wire  ref_off_O_hdmi_hsync;
wire  ref_off_O_hdmi_de;
wire [23:0] ref_off_O_hdmi_data;
wire [23:0] ref_off_O_base_data;
wire  ref_off_O_overlay_valid;
hdmi_mixer_image9_ref #(.SPRITE_ENABLE(0),.DEBUG_MODE(DEBUG_TEST)) ref_off(
.I_clk(I_clk),
.I_rst_n(I_rst_n),
.I_video_vsync(I_video_vsync),
.I_video_hsync(I_video_hsync),
.I_video_de(I_video_de),
.I_video_user(I_video_user),
.I_video_last(I_video_last),
.I_debug_status(I_debug_status),
.I_dbg_mode(I_dbg_mode),
.I_dbg_step(I_dbg_step),
.I_dbg_effect(I_dbg_effect),
.I_dbg_awb_off(I_dbg_awb_off),
.I_recog_mode(I_recog_mode),
.I_logo_enable(I_logo_enable),
.I_motion_target(I_motion_target),
.I_dbg_sat_pre(I_dbg_sat_pre),
.I_dbg_sat_post(I_dbg_sat_post),
.I_dbg_mean_r(I_dbg_mean_r),
.I_dbg_mean_g(I_dbg_mean_g),
.I_dbg_mean_b(I_dbg_mean_b),
.I_dbg_min_r(I_dbg_min_r),
.I_dbg_noise(I_dbg_noise),
.I_dbg_mean_y(I_dbg_mean_y),
.I_shape_valid(I_shape_valid),
.I_shape_type(I_shape_type),
.I_shape_x0(I_shape_x0),
.I_shape_y0(I_shape_y0),
.I_shape_x1(I_shape_x1),
.I_shape_y1(I_shape_y1),
.I_motion_valid(I_motion_valid),
.I_motion_count(I_motion_count),
.I_motion_tvalid(I_motion_tvalid),
.I_motion_x0_0(I_motion_x0_0),
.I_motion_y0_0(I_motion_y0_0),
.I_motion_x1_0(I_motion_x1_0),
.I_motion_y1_0(I_motion_y1_0),
.I_motion_x0_1(I_motion_x0_1),
.I_motion_y0_1(I_motion_y0_1),
.I_motion_x1_1(I_motion_x1_1),
.I_motion_y1_1(I_motion_y1_1),
.I_motion_x0_2(I_motion_x0_2),
.I_motion_y0_2(I_motion_y0_2),
.I_motion_x1_2(I_motion_x1_2),
.I_motion_y1_2(I_motion_y1_2),
.I_color_valid(I_color_valid),
.I_color_code(I_color_code),
.I_color_count(I_color_count),
.I_color_x0(I_color_x0),
.I_color_y0(I_color_y0),
.I_color_x1(I_color_x1),
.I_color_y1(I_color_y1),
.I_track_new(I_track_new),
.I_track_valid(I_track_valid),
.I_track_state(I_track_state),
.I_track_dx(I_track_dx),
.I_track_dy(I_track_dy),
.I_track_lx(I_track_lx),
.I_track_ly(I_track_ly),
.I_track_x0(I_track_x0),
.I_track_y0(I_track_y0),
.I_track_x1(I_track_x1),
.I_track_y1(I_track_y1),
.I_track_cx(I_track_cx),
.I_track_cy(I_track_cy),
.I_track_ex(I_track_ex),
.I_track_ey(I_track_ey),
.I_track_area(I_track_area),
.I_video_rd_data(I_video_rd_data),
.O_video_rd_en(ref_off_O_video_rd_en),
.O_hdmi_vsync(ref_off_O_hdmi_vsync),
.O_hdmi_hsync(ref_off_O_hdmi_hsync),
.O_hdmi_de(ref_off_O_hdmi_de),
.O_hdmi_data(ref_off_O_hdmi_data),
.O_base_data(ref_off_O_base_data),
.O_overlay_valid(ref_off_O_overlay_valid));
wire  dut_off_O_video_rd_en;
wire  dut_off_O_hdmi_vsync;
wire  dut_off_O_hdmi_hsync;
wire  dut_off_O_hdmi_de;
wire [23:0] dut_off_O_hdmi_data;
wire [23:0] dut_off_O_base_data;
wire  dut_off_O_overlay_valid;
hdmi_mixer_image9 #(.SPRITE_ENABLE(0),.DEBUG_MODE(DEBUG_TEST)) dut_off(
.I_clk(I_clk),
.I_rst_n(I_rst_n),
.I_video_vsync(I_video_vsync),
.I_video_hsync(I_video_hsync),
.I_video_de(I_video_de),
.I_video_user(I_video_user),
.I_video_last(I_video_last),
.I_debug_status(I_debug_status),
.I_dbg_mode(I_dbg_mode),
.I_dbg_step(I_dbg_step),
.I_dbg_effect(I_dbg_effect),
.I_dbg_awb_off(I_dbg_awb_off),
.I_recog_mode(I_recog_mode),
.I_logo_enable(I_logo_enable),
.I_motion_target(I_motion_target),
.I_dbg_sat_pre(I_dbg_sat_pre),
.I_dbg_sat_post(I_dbg_sat_post),
.I_dbg_mean_r(I_dbg_mean_r),
.I_dbg_mean_g(I_dbg_mean_g),
.I_dbg_mean_b(I_dbg_mean_b),
.I_dbg_min_r(I_dbg_min_r),
.I_dbg_noise(I_dbg_noise),
.I_dbg_mean_y(I_dbg_mean_y),
.I_shape_valid(I_shape_valid),
.I_shape_type(I_shape_type),
.I_shape_x0(I_shape_x0),
.I_shape_y0(I_shape_y0),
.I_shape_x1(I_shape_x1),
.I_shape_y1(I_shape_y1),
.I_motion_valid(I_motion_valid),
.I_motion_count(I_motion_count),
.I_motion_tvalid(I_motion_tvalid),
.I_motion_x0_0(I_motion_x0_0),
.I_motion_y0_0(I_motion_y0_0),
.I_motion_x1_0(I_motion_x1_0),
.I_motion_y1_0(I_motion_y1_0),
.I_motion_x0_1(I_motion_x0_1),
.I_motion_y0_1(I_motion_y0_1),
.I_motion_x1_1(I_motion_x1_1),
.I_motion_y1_1(I_motion_y1_1),
.I_motion_x0_2(I_motion_x0_2),
.I_motion_y0_2(I_motion_y0_2),
.I_motion_x1_2(I_motion_x1_2),
.I_motion_y1_2(I_motion_y1_2),
.I_color_valid(I_color_valid),
.I_color_code(I_color_code),
.I_color_count(I_color_count),
.I_color_x0(I_color_x0),
.I_color_y0(I_color_y0),
.I_color_x1(I_color_x1),
.I_color_y1(I_color_y1),
.I_track_new(I_track_new),
.I_track_valid(I_track_valid),
.I_track_state(I_track_state),
.I_track_dx(I_track_dx),
.I_track_dy(I_track_dy),
.I_track_lx(I_track_lx),
.I_track_ly(I_track_ly),
.I_track_x0(I_track_x0),
.I_track_y0(I_track_y0),
.I_track_x1(I_track_x1),
.I_track_y1(I_track_y1),
.I_track_cx(I_track_cx),
.I_track_cy(I_track_cy),
.I_track_ex(I_track_ex),
.I_track_ey(I_track_ey),
.I_track_area(I_track_area),
.I_video_rd_data(I_video_rd_data),
.O_video_rd_en(dut_off_O_video_rd_en),
.O_hdmi_vsync(dut_off_O_hdmi_vsync),
.O_hdmi_hsync(dut_off_O_hdmi_hsync),
.O_hdmi_de(dut_off_O_hdmi_de),
.O_hdmi_data(dut_off_O_hdmi_data),
.O_base_data(dut_off_O_base_data),
.O_overlay_valid(dut_off_O_overlay_valid));
wire  ref_on_O_video_rd_en;
wire  ref_on_O_hdmi_vsync;
wire  ref_on_O_hdmi_hsync;
wire  ref_on_O_hdmi_de;
wire [23:0] ref_on_O_hdmi_data;
wire [23:0] ref_on_O_base_data;
wire  ref_on_O_overlay_valid;
hdmi_mixer_image9_ref #(.SPRITE_ENABLE(1),.DEBUG_MODE(DEBUG_TEST)) ref_on(
.I_clk(I_clk),
.I_rst_n(I_rst_n),
.I_video_vsync(I_video_vsync),
.I_video_hsync(I_video_hsync),
.I_video_de(I_video_de),
.I_video_user(I_video_user),
.I_video_last(I_video_last),
.I_debug_status(I_debug_status),
.I_dbg_mode(I_dbg_mode),
.I_dbg_step(I_dbg_step),
.I_dbg_effect(I_dbg_effect),
.I_dbg_awb_off(I_dbg_awb_off),
.I_recog_mode(I_recog_mode),
.I_logo_enable(I_logo_enable),
.I_motion_target(I_motion_target),
.I_dbg_sat_pre(I_dbg_sat_pre),
.I_dbg_sat_post(I_dbg_sat_post),
.I_dbg_mean_r(I_dbg_mean_r),
.I_dbg_mean_g(I_dbg_mean_g),
.I_dbg_mean_b(I_dbg_mean_b),
.I_dbg_min_r(I_dbg_min_r),
.I_dbg_noise(I_dbg_noise),
.I_dbg_mean_y(I_dbg_mean_y),
.I_shape_valid(I_shape_valid),
.I_shape_type(I_shape_type),
.I_shape_x0(I_shape_x0),
.I_shape_y0(I_shape_y0),
.I_shape_x1(I_shape_x1),
.I_shape_y1(I_shape_y1),
.I_motion_valid(I_motion_valid),
.I_motion_count(I_motion_count),
.I_motion_tvalid(I_motion_tvalid),
.I_motion_x0_0(I_motion_x0_0),
.I_motion_y0_0(I_motion_y0_0),
.I_motion_x1_0(I_motion_x1_0),
.I_motion_y1_0(I_motion_y1_0),
.I_motion_x0_1(I_motion_x0_1),
.I_motion_y0_1(I_motion_y0_1),
.I_motion_x1_1(I_motion_x1_1),
.I_motion_y1_1(I_motion_y1_1),
.I_motion_x0_2(I_motion_x0_2),
.I_motion_y0_2(I_motion_y0_2),
.I_motion_x1_2(I_motion_x1_2),
.I_motion_y1_2(I_motion_y1_2),
.I_color_valid(I_color_valid),
.I_color_code(I_color_code),
.I_color_count(I_color_count),
.I_color_x0(I_color_x0),
.I_color_y0(I_color_y0),
.I_color_x1(I_color_x1),
.I_color_y1(I_color_y1),
.I_track_new(I_track_new),
.I_track_valid(I_track_valid),
.I_track_state(I_track_state),
.I_track_dx(I_track_dx),
.I_track_dy(I_track_dy),
.I_track_lx(I_track_lx),
.I_track_ly(I_track_ly),
.I_track_x0(I_track_x0),
.I_track_y0(I_track_y0),
.I_track_x1(I_track_x1),
.I_track_y1(I_track_y1),
.I_track_cx(I_track_cx),
.I_track_cy(I_track_cy),
.I_track_ex(I_track_ex),
.I_track_ey(I_track_ey),
.I_track_area(I_track_area),
.I_video_rd_data(I_video_rd_data),
.O_video_rd_en(ref_on_O_video_rd_en),
.O_hdmi_vsync(ref_on_O_hdmi_vsync),
.O_hdmi_hsync(ref_on_O_hdmi_hsync),
.O_hdmi_de(ref_on_O_hdmi_de),
.O_hdmi_data(ref_on_O_hdmi_data),
.O_base_data(ref_on_O_base_data),
.O_overlay_valid(ref_on_O_overlay_valid));
wire  dut_on_O_video_rd_en;
wire  dut_on_O_hdmi_vsync;
wire  dut_on_O_hdmi_hsync;
wire  dut_on_O_hdmi_de;
wire [23:0] dut_on_O_hdmi_data;
wire [23:0] dut_on_O_base_data;
wire  dut_on_O_overlay_valid;
hdmi_mixer_image9 #(.SPRITE_ENABLE(1),.DEBUG_MODE(DEBUG_TEST)) dut_on(
.I_clk(I_clk),
.I_rst_n(I_rst_n),
.I_video_vsync(I_video_vsync),
.I_video_hsync(I_video_hsync),
.I_video_de(I_video_de),
.I_video_user(I_video_user),
.I_video_last(I_video_last),
.I_debug_status(I_debug_status),
.I_dbg_mode(I_dbg_mode),
.I_dbg_step(I_dbg_step),
.I_dbg_effect(I_dbg_effect),
.I_dbg_awb_off(I_dbg_awb_off),
.I_recog_mode(I_recog_mode),
.I_logo_enable(I_logo_enable),
.I_motion_target(I_motion_target),
.I_dbg_sat_pre(I_dbg_sat_pre),
.I_dbg_sat_post(I_dbg_sat_post),
.I_dbg_mean_r(I_dbg_mean_r),
.I_dbg_mean_g(I_dbg_mean_g),
.I_dbg_mean_b(I_dbg_mean_b),
.I_dbg_min_r(I_dbg_min_r),
.I_dbg_noise(I_dbg_noise),
.I_dbg_mean_y(I_dbg_mean_y),
.I_shape_valid(I_shape_valid),
.I_shape_type(I_shape_type),
.I_shape_x0(I_shape_x0),
.I_shape_y0(I_shape_y0),
.I_shape_x1(I_shape_x1),
.I_shape_y1(I_shape_y1),
.I_motion_valid(I_motion_valid),
.I_motion_count(I_motion_count),
.I_motion_tvalid(I_motion_tvalid),
.I_motion_x0_0(I_motion_x0_0),
.I_motion_y0_0(I_motion_y0_0),
.I_motion_x1_0(I_motion_x1_0),
.I_motion_y1_0(I_motion_y1_0),
.I_motion_x0_1(I_motion_x0_1),
.I_motion_y0_1(I_motion_y0_1),
.I_motion_x1_1(I_motion_x1_1),
.I_motion_y1_1(I_motion_y1_1),
.I_motion_x0_2(I_motion_x0_2),
.I_motion_y0_2(I_motion_y0_2),
.I_motion_x1_2(I_motion_x1_2),
.I_motion_y1_2(I_motion_y1_2),
.I_color_valid(I_color_valid),
.I_color_code(I_color_code),
.I_color_count(I_color_count),
.I_color_x0(I_color_x0),
.I_color_y0(I_color_y0),
.I_color_x1(I_color_x1),
.I_color_y1(I_color_y1),
.I_track_new(I_track_new),
.I_track_valid(I_track_valid),
.I_track_state(I_track_state),
.I_track_dx(I_track_dx),
.I_track_dy(I_track_dy),
.I_track_lx(I_track_lx),
.I_track_ly(I_track_ly),
.I_track_x0(I_track_x0),
.I_track_y0(I_track_y0),
.I_track_x1(I_track_x1),
.I_track_y1(I_track_y1),
.I_track_cx(I_track_cx),
.I_track_cy(I_track_cy),
.I_track_ex(I_track_ex),
.I_track_ey(I_track_ey),
.I_track_area(I_track_area),
.I_video_rd_data(I_video_rd_data),
.O_video_rd_en(dut_on_O_video_rd_en),
.O_hdmi_vsync(dut_on_O_hdmi_vsync),
.O_hdmi_hsync(dut_on_O_hdmi_hsync),
.O_hdmi_de(dut_on_O_hdmi_de),
.O_hdmi_data(dut_on_O_hdmi_data),
.O_base_data(dut_on_O_base_data),
.O_overlay_valid(dut_on_O_overlay_valid));

reg [13:0] rom_addr=0;
wire [24:0] rom_expected,rom_actual;
reg [24:0] sampled_expected;
anlogic_logo_rom_ref rom_ref(.I_addr(rom_addr),.O_pixel(rom_expected));
anlogic_logo_rom rom_dut(.I_clk(I_clk),.I_addr(rom_addr),.O_pixel(rom_actual));
integer cycles=0, rom_checks=0, differences=0, sprite_pixels=0, logo_pixels=0;
integer x,y,k,fx=0,fy=0;
integer seed=731602;
task check;
begin
    @(posedge I_clk); #1;
    cycles=cycles+1;
    if({ref_off_O_video_rd_en,ref_off_O_hdmi_vsync,ref_off_O_hdmi_hsync,ref_off_O_hdmi_de,ref_off_O_hdmi_data,ref_off_O_base_data,ref_off_O_overlay_valid} !== {dut_off_O_video_rd_en,dut_off_O_hdmi_vsync,dut_off_O_hdmi_hsync,dut_off_O_hdmi_de,dut_off_O_hdmi_data,dut_off_O_base_data,dut_off_O_overlay_valid}) $fatal(1,"Mixer mismatch ref_off: cycle=%0d x=%0d y=%0d de=%b rgb=%h/%h",cycles,fx,fy,ref_off_O_hdmi_de,ref_off_O_hdmi_data,dut_off_O_hdmi_data);
    if(I_rst_n && (^{dut_off_O_video_rd_en,dut_off_O_hdmi_vsync,dut_off_O_hdmi_hsync,dut_off_O_hdmi_de,dut_off_O_hdmi_data,dut_off_O_base_data,dut_off_O_overlay_valid}) === 1'bx) $fatal(1,"Unknown output dut_off, cycle=%0d",cycles);
    if({ref_on_O_video_rd_en,ref_on_O_hdmi_vsync,ref_on_O_hdmi_hsync,ref_on_O_hdmi_de,ref_on_O_hdmi_data,ref_on_O_base_data,ref_on_O_overlay_valid} !== {dut_on_O_video_rd_en,dut_on_O_hdmi_vsync,dut_on_O_hdmi_hsync,dut_on_O_hdmi_de,dut_on_O_hdmi_data,dut_on_O_base_data,dut_on_O_overlay_valid}) $fatal(1,"Mixer mismatch ref_on: cycle=%0d x=%0d y=%0d de=%b rgb=%h/%h",cycles,fx,fy,ref_on_O_hdmi_de,ref_on_O_hdmi_data,dut_on_O_hdmi_data);
    if(I_rst_n && (^{dut_on_O_video_rd_en,dut_on_O_hdmi_vsync,dut_on_O_hdmi_hsync,dut_on_O_hdmi_de,dut_on_O_hdmi_data,dut_on_O_base_data,dut_on_O_overlay_valid}) === 1'bx) $fatal(1,"Unknown output dut_on, cycle=%0d",cycles);

    if(dut_off_O_hdmi_de && dut_off_O_hdmi_data !== dut_on_O_hdmi_data) differences=differences+1;
    if(dut_on.S_osd_hit_1d && !dut_off.S_osd_hit_1d) sprite_pixels=sprite_pixels+1;
    if(dut_off.S_l1_hit_1d) logo_pixels=logo_pixels+1;
end
endtask
initial begin
    repeat(4) check();
    @(negedge I_clk); I_rst_n=1; I_logo_enable=1; I_dbg_step=2;
    // Exhaust the entire legacy address space, including transparency and
    // addresses above the physical ROM capacity. Mix blank video concurrently.
    for(k=0;k<16384;k=k+1) begin
        @(negedge I_clk); rom_addr=k; #1; sampled_expected=rom_expected;
        check();
        if(rom_actual!==sampled_expected) $fatal(1,"ROM mismatch address=%d",k);
        rom_checks=rom_checks+1;
    end
    // Complete raster: crosses every fixed-logo/text pixel, sprite pixels,
    // line boundaries and blanking. Compare all external outputs every cycle.
    @(negedge I_clk); I_video_user=1;
    repeat(4) check();
    @(negedge I_clk); I_video_user=0;
    for(y=0;y<1082;y=y+1) begin
        for(x=0;x<1928;x=x+1) begin
            @(negedge I_clk);
            I_video_de=(x<1920 && y<1080);
            I_video_hsync=(x>=1924);
            I_video_vsync=(y>=1080);
            I_video_rd_data={x[7:0],y[7:0],x[7:0]^y[7:0]};
            fx=x;fy=y;check();
        end
    end
    // Random jumps stress coordinate/control alignment without waiting for
    // full frames. Force only the common coordinate counters, never outputs.
    force ref_off.S_x=fx; force ref_off.S_y=fy;
    force dut_off.S_x=fx; force dut_off.S_y=fy;
    force ref_on.S_x=fx; force ref_on.S_y=fy;
    force dut_on.S_x=fx; force dut_on.S_y=fy;
    for(k=0;k<40000;k=k+1) begin
        @(negedge I_clk);
        fx=$unsigned($random(seed))%1920;fy=$unsigned($random(seed))%1080;
        if(k%3==0) begin fx=$unsigned($random(seed))%200;fy=$unsigned($random(seed))%200;end
        I_video_de=$random(seed); I_video_user=(k%3==0);
        I_video_vsync=$random(seed);I_video_hsync=$random(seed);
        I_video_rd_data=$random(seed);I_logo_enable=$random(seed);
        I_recog_mode=$random(seed);I_dbg_mode=$unsigned($random(seed))%6;
        I_dbg_effect=$unsigned($random(seed))%6;
        I_dbg_awb_off=$random(seed);I_dbg_step=$unsigned($random(seed))%6;
        I_shape_valid=$random(seed);I_shape_type=$unsigned($random(seed))%6;
        I_shape_x0=20;I_shape_y0=20;I_shape_x1=160;I_shape_y1=160;
        I_motion_valid=$random(seed);I_motion_tvalid=$random(seed);I_motion_count=$random(seed);
        I_motion_x0_0=20;I_motion_y0_0=20;I_motion_x1_0=160;I_motion_y1_0=160;
        I_color_valid=$random(seed);I_color_code=$random(seed);I_color_count=$random(seed);
        I_color_x0=20;I_color_y0=20;I_color_x1=160;I_color_y1=160;
        I_rst_n=(k%997!=0);
        check();
    end
    if((DEBUG_TEST==0 && differences==0) || sprite_pixels==0 || logo_pixels==0) $fatal(1,"Missing coverage");
    $display("PASS OSD: debug=%0d cycles=%0d ROM=%0d visible_sprite_differences=%0d sprite_pixels=%0d logo_pixels=%0d",DEBUG_TEST,cycles,rom_checks,differences,sprite_pixels,logo_pixels);
    $finish;
end
initial begin #100000000; $fatal(1,"timeout");end
endmodule
