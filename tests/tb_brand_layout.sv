`timescale 1ns/1ps
module tb_brand_layout;
    reg clk=0,rst=0,logo=1;
    reg [11:0] x=0,y=0;
    integer hits=0;
    always #5 clk=~clk;
    hdmi_mixer_image9 dut(.I_clk(clk),.I_rst_n(rst),.I_logo_enable(logo),
        .I_recog_mode(1'b0),.I_dbg_mode(3'd5),.I_dbg_awb_off(1'b0),
        .I_video_de(1'b0),.I_video_vsync(1'b0),.I_video_hsync(1'b0),
        .I_video_user(1'b0),.I_video_last(1'b0),.I_video_rd_data(24'd0));
    initial begin
        force dut.S_x=x;force dut.S_y_pix=y;force dut.S_video_de_2d=1;
        #20;rst=1;
        for(integer yy=12;yy<66;yy++)for(integer xx=8;xx<272;xx++)begin
            x=xx;y=yy;#1;if(dut.S_dbg_hit!==0)$fatal(1,"diagnostic bar remains");
        end
        for(integer yy=184;yy<248;yy++)for(integer xx=32;xx<160;xx++)begin
            x=xx;y=yy;#1;
            if(dut.S_osd_hit)begin
                hits++;if(dut.S_osd_color!==24'hfff200)$fatal(1,"label color");
            end
        end
        if(hits<100)$fatal(1,"label missing below logo");
        logo=0;x=60;y=200;#1;if(dut.S_osd_hit!==0)$fatal(1,"logo switch");
        logo=1;
        for(integer yy=40;yy<104;yy++)for(integer xx=896;xx<1024;xx++)begin
            x=xx;y=yy;#1;if(dut.S_osd_hit!==0)$fatal(1,"old centered label remains");
        end
        $display("PASS brand: diagnostic panel removed, %0d label pixels below logo, old center clear",hits);
        $finish;
    end
endmodule
