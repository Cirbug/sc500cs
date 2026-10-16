`timescale 1ns/1ps
module tb_picture_osd;
    reg clk=0; always #5 clk=~clk;
    reg rst=0,vs=0,de=0;
    wire [23:0] pixel;
    integer px,py,fd,i;
    integer values[0:6];
    ui_osd #(.MENU_CHINESE(0)) dut(.I_mipi_clk(clk),.I_mipi_frame_start(1'b0),.I_camera_display({7'd127,16'h2000}),.I_clk(clk),.I_rst_n(rst),.I_vsync(vs),.I_hsync(1'b0),.I_de(de),
        .I_data(24'h526879),.I_menu_enable(1'b1),.I_edit_enable(1'b1),.I_info_enable(1'b0),
        .I_menu_index(3'd5),.I_picture_page(1'b1),.I_picture_ctrl(16'h1050),
        .I_exposure(16'd5990),.I_gain(16'd80),.I_servo_pan_us(16'd1500),.I_servo_tilt_us(16'd1500),
        .I_rtc_hours(8'h12),.I_rtc_minutes(8'h34),.I_rtc_seconds(8'h56),
        .I_rtc_valid(1'b1),.I_rtc_error(1'b0),.I_rtc_osf(1'b0),.O_data(pixel));
    initial begin
        fd=$fopen("picture_menu_preview.ppm","w");
        $fwrite(fd,"P3\n468 324\n255\n");
        for(i=0;i<7;i=i+1) values[i]=0;
        repeat(3) @(negedge clk); rst=1; vs=1;
        @(negedge clk); vs=0;
        for(py=0;py<1004;py=py+1) begin
            de=1;
            for(px=0;px<1920;px=px+1) begin
                @(posedge clk); #1;
                if(px>=24 && px<492 && py>=644)
                    $fwrite(fd,"%d %d %d\n",pixel[23:16],pixel[15:8],pixel[7:0]);
                if(px>=330 && px<458 && py>=696 && py<940 && pixel===24'h80e0c0)
                    values[(py-696)/36]=values[(py-696)/36]+1;
                if((px==600 || px==1200) && pixel!==24'h526879) $fatal(1,"overlay escaped menu");
                @(negedge clk);
            end
            de=0; repeat(2) @(negedge clk);
        end
        for(i=0;i<7;i=i+1) if(values[i]==0) $fatal(1,"missing setting value row %d",i);
        $fclose(fd); $display("PASS picture page values and bounds"); $finish;
    end
endmodule
