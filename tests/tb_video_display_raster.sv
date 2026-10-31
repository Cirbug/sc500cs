`timescale 1ns/1ps
// Check real display FIFO/unpacker with spatially distinct pixels. The DDR
// model returns an address-coded RGB888 stream; no physical DDR is modeled.
module tb_video_display_raster;
    localparam WIDTH=1920, HEIGHT=1080, WORDS=WIDTH*HEIGHT*3/16;
    localparam STRIDE=3200000;
    reg d=0,p=0,rst_n=0,vs=0,rd=0;
    always #3.75 d=~d;
    always #6.666 p=~p;
    reg [1:0] bank=0;
    wire re,busy,reader_valid;
    wire [1:0] reader_bank;
    wire [24:0] addr;
    wire [23:0] pixel;
    wire [31:0] diag;
    integer cycle=0,produced=0,consumed=0,requested=0,checked=0;
    integer due[0:1023];
    reg [127:0] replies[0:1023];
    wire response=produced!=consumed && cycle>=due[consumed%1024];
    wire ready=(cycle%257)>15;
    video_out dut(.I_rst_n(rst_n),.I_ddr_clk(d),.O_video_out_rd_busy(busy),
        .I_video_in_wr_busy(1'b0),.I_video_out_rp(bank),.I_video_out_valid(1'b1),
        .O_reader_bank(reader_bank),.O_reader_valid(reader_valid),.O_display_diag(diag),
        .O_ddr_user_rd_en(re),.O_ddr_user_addr(addr),.I_ddr_user_ready(ready),
        .I_ddr_user_rd_valid(response),.I_ddr_user_rd_data(replies[consumed%1024]),
        .I_dsi_clk(p),.I_video_vsync(vs),.I_video_rd_en(rd),.O_vdieo_data(pixel));

    function automatic [23:0] expected(input integer b,input integer index);
        // Pixel position is unique throughout the frame, plus a bank tag.
        expected=24'h100000+b*24'h300000+index;
    endfunction
    function automatic [127:0] word_at(input integer b,input integer w);
        reg [127:0] result;
        reg [23:0] rgb;
        integer byte_index;
        begin
            for(integer j=0;j<16;j=j+1) begin
                byte_index=w*16+j;
                rgb=expected(b,byte_index/3);
                case(byte_index%3)
                    0:result[127-j*8 -: 8]=rgb[23:16];
                    1:result[127-j*8 -: 8]=rgb[15:8];
                    2:result[127-j*8 -: 8]=rgb[7:0];
                endcase
            end
            word_at=result;
        end
    endfunction
    always @(posedge d) if(rst_n) begin
        cycle<=cycle+1;
        if(response) consumed<=consumed+1;
        if(re) begin
            if(produced-consumed>=1024) $fatal(1,"response queue overflow");
            if(addr%STRIDE!=requested*8) $fatal(1,"DDR address sequence: %d word=%d",addr,requested);
            replies[produced%1024]<=word_at(addr/STRIDE,(addr%STRIDE)/8);
            due[produced%1024]<=cycle+32;
            produced<=produced+1;
            requested<=requested+1;
        end
    end
    reg delayed_rd=0,check_enable=0,check_rd=0;
    integer index=0,display_bank=0;
    always @(posedge p) begin
        delayed_rd=rd;
        // video_out consumes the non-show-ahead FIFO result one clock later.
        #0.001;
        if(rst_n && check_enable) begin
            if(check_rd) begin
                if(pixel!==expected(display_bank,index))
                    $fatal(1,"pixel mismatch bank=%d x=%d y=%d got=%h expected=%h diag=%h",
                        display_bank,index%WIDTH,index/WIDTH,pixel,expected(display_bank,index),diag);
                index=index+1;checked=checked+1;
            end
        end
        check_rd=delayed_rd;
    end
    task display_frame(input integer b);
        begin
            @(negedge p);bank=b;vs=1;
            repeat(5*2200) @(negedge p);
            vs=0;
            repeat(36*2200) @(negedge p);
            display_bank=b;index=0;check_enable=1;
            for(integer y=0;y<HEIGHT;y=y+1) begin
                rd=1;repeat(WIDTH) @(negedge p);
                rd=0;repeat(280) @(negedge p);
            end
            check_enable=0;
            if(index!=WIDTH*HEIGHT || requested!=WORDS || diag!=0)
                $fatal(1,"frame coverage pixels=%d requests=%d diag=%h",index,requested,diag);
            $display("PASS raster bank=%0d pixels=%0d requests=%0d C8=%h",b,index,requested,diag);
            requested=0;
        end
    endtask
    initial begin
        repeat(20) @(negedge p);rst_n=1;
        // The first VS starts reading before any pixel requests.
        display_frame(0);display_frame(2);
        if(checked!=2*WIDTH*HEIGHT) $fatal(1,"missing checked pixels");
        $display("PASS full 1920x1080 raster, all pixel positions and bank switch verified");
        $finish;
    end
    initial begin #100000000;$fatal(1,"timeout");end
endmodule
