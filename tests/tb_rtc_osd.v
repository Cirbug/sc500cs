`timescale 1ns/1ps
// Feed real active-video coordinates and inspect the resulting clock pixels.
module tb_rtc_osd;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, vs=0, de=0;
    reg [7:0] hours=8'h12, minutes=8'h34, seconds=8'h56;
    reg [7:0] year=8'h26,month=8'h10,date=8'h18;
    reg [79:0] expected_date="2026-10-18";
    reg date_healthy=1;
    reg valid=1, error=0, osf=0;
    wire ovs, ohs, ode;
    wire [23:0] pixel;
    ui_osd #(.MENU_CHINESE(0)) dut(.I_mipi_clk(clk),.I_mipi_frame_start(1'b0),.I_camera_display({7'd127,16'h2000}),
        .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vs), .I_hsync(1'b0),
        .I_de(de), .I_data(24'h526879), .I_menu_enable(1'b0),
        .I_edit_enable(1'b0), .I_info_enable(1'b0), .I_menu_index(3'd0),
        .I_exposure(16'd5990), .I_gain(16'd80),
        .I_servo_pan_us(16'd1500), .I_servo_tilt_us(16'd1500),
        .I_rtc_hours(hours), .I_rtc_minutes(minutes), .I_rtc_seconds(seconds),
        .I_rtc_year(year),.I_rtc_month(month),.I_rtc_date(date),
        .I_rtc_valid(valid), .I_rtc_error(error), .I_rtc_osf(osf),
        .O_vsync(ovs), .O_hsync(ohs), .O_de(ode), .O_data(pixel));

    task tick;
        begin
            @(posedge clk); #1;
            if({ovs,ohs,ode} !== {vs,1'b0,de}) $fatal(1,"Control alignment");
            if(!de && pixel!==0) $fatal(1,"Blanking pixel");
            @(negedge clk);
        end
    endtask

    // Independent expected first-row bitmap, sufficient to distinguish each
    // hour tens/ones used below and all six positions in HH:MM:SS.
    function [4:0] first_row;
        input [7:0] c;
        begin
            case(c)
                "0","2","6","8","9": first_row=5'b01110;
                "1": first_row=5'b00100;
                "3": first_row=5'b11110;
                "4": first_row=5'b00010;
                "5","7": first_row=5'b11111;
                default: first_row=0;
            endcase
        end
    endfunction

    task frame;
        input [63:0] expected;
        input healthy;
        input change_mid_frame;
        integer px,py,cell_no,col;
        reg [7:0] c;
        reg [4:0] bits;
        reg [23:0] expected_pixel;
        begin
            vs=1; tick(); vs=0; tick();
            for(py=0;py<98;py=py+1) begin
                de=1;
                for(px=0;px<1920;px=px+1) begin
                    if(change_mid_frame && py==26 && px==890) begin
                        hours=8'h23; minutes=8'h59; seconds=8'h59;
                        year=8'h27;month=1;date=1;
                    end
                    tick();
                    if((px<818 || px>=1102 || py<16 || py>=96) && !(px>=1440 && px<1904 && py>=16 && py<168)) begin
                        if(pixel!==24'h526879) $fatal(1,"Passthrough at %d,%d",px,py);
                    end
                    if(px==818 && py==16 &&
                       pixel!==(healthy ? 24'h304652 : 24'h904030))
                        $fatal(1,"Clock health border");
                    if(px>=838 && px<1094 && py==58) begin
                        cell_no=(px-838)/32; col=((px-838)%32)/4;
                        c=expected[63-cell_no*8 -: 8]; bits=first_row(c);
                        expected_pixel=(col<5 && (bits & (5'b10000>>col))) ?
                            (healthy ? 24'hffffff : 24'hffb080) : 24'h101820;
                        if(pixel!==expected_pixel)
                            $fatal(1,"Clock digit %d x=%d char=%h pixel=%h expected=%h",cell_no,px,c,pixel,expected_pixel);
                    end
                    if(px>=883 && px<1043 && py==26) begin
                        cell_no=(px-883)/16;col=((px-883)%16)/2;
                        c=(healthy && date_healthy)?expected_date[79-cell_no*8 -: 8]:"-";
                        bits=first_row(c);
                        expected_pixel=(col<5 && (bits & (5'b10000>>col))) ?
                            ((healthy && date_healthy)?24'ha6b6c4:24'hffb080):24'h101820;
                        if(pixel!==expected_pixel)$fatal(1,"Date digit %d char=%h pixel=%h expected=%h",cell_no,c,pixel,expected_pixel);
                    end
                    if(!healthy && py==70 && px>=838 && px<858 && pixel!==24'hffb080)
                        $fatal(1,"Missing invalid-time dash");
                end
                de=0; tick(); tick();
            end
        end
    endtask

    initial begin
        repeat(2) @(negedge clk); rst_n=1;
        frame("12:34:56",1,1);
        expected_date="2027-01-01";
        frame("23:59:59",1,0);
        hours=0; minutes=0; seconds=0; frame("00:00:00",1,0);
        hours=8'h52; frame("00:00:00",1,0); // 12 AM
        hours=8'h72; frame("12:00:00",1,0); // 12 PM
        hours=8'h61; frame("13:00:00",1,0); // 1 PM
        error=1; frame("--:--:--",0,0); error=0;
        osf=1; frame("--:--:--",0,0); osf=0;
        minutes=8'h6a; frame("--:--:--",0,0);
        minutes=0; hours=8'h40; frame("--:--:--",0,0); // invalid 12h value
        hours=0;year=0;month=8'h81;date=1;expected_date="2100-01-01";frame("00:00:00",1,0);
        date=0;date_healthy=0;frame("00:00:00",1,0);
        date=1;month=8'h1a;frame("00:00:00",1,0);
        month=1;year=8'hfa;frame("00:00:00",1,0);
        $display("PASS: top-center YYYY-MM-DD / HH:MM:SS, century, atomic date/time frame freeze, 12h, error/OSF/invalid BCD, passthrough");
        $finish;
    end
    initial begin #50000000; $fatal(1,"Timeout"); end
endmodule
