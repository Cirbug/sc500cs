module design_0_hdmi_phy_wrapper_0 
#(
    parameter DEVICE = "EG"
)
(
    input             I_pixel_clk ,
    input             I_serial_clk ,
    input             I_rst ,
    input       [9:0] I_tmds_channel_0 ,
    input       [9:0] I_tmds_channel_1 ,
    input       [9:0] I_tmds_channel_2 ,
    input       [9:0] I_tmds_channel_clk ,
    output            O_tmds_ch0_p ,
    output            O_tmds_ch1_p ,
    output            O_tmds_ch2_p ,
    output            O_tmds_clk_p
) ;

    hdmi_phy_wrapper #(
        .DEVICE(DEVICE)
    ) hdmi_phy_wrapper (
        .I_pixel_clk(I_pixel_clk) ,
        .I_serial_clk(I_serial_clk) ,
        .I_rst(I_rst) ,
        .I_tmds_channel_0(I_tmds_channel_0) ,
        .I_tmds_channel_1(I_tmds_channel_1) ,
        .I_tmds_channel_2(I_tmds_channel_2) ,
        .I_tmds_channel_clk(I_tmds_channel_clk) ,
        .O_tmds_ch0_p(O_tmds_ch0_p) ,
        .O_tmds_ch1_p(O_tmds_ch1_p) ,
        .O_tmds_ch2_p(O_tmds_ch2_p) ,
        .O_tmds_clk_p(O_tmds_clk_p)
    );


endmodule
