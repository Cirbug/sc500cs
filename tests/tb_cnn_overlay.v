`timescale 1ns/1ps
module tb_cnn_overlay;
    reg clk=0,rst_n=0,enable=0,valid=0,busy=0,vs=0,hs=0,de=0;
    reg [639:0] records=0;reg [4:0] count=0;reg [15:0] result_generation=0;
    reg [23:0] source_rgb=24'h123456;
    wire ovs,ohs,ode;wire [23:0] rgb;
    always #5 clk=~clk;
    cnn_digit_overlay d(.clk(clk),.rst_n(rst_n),.enable(enable),.result_valid(valid),.result_busy(busy),
        .result_count(count),.result_generation(result_generation),.result_records(records),
        .vs(vs),.hs(hs),.de(de),.rgb(source_rgb),
        .out_vs(ovs),.out_hs(ohs),.out_de(ode),.out_rgb(rgb));
    task sync_frame;
        begin @(negedge clk);vs=1;de=0;repeat(2)@(negedge clk);vs=0;repeat(80000)@(negedge clk);end
    endtask
    // Class 1 in a 5x7 font, with a separate 4x scale expected raster.
    function is_ink;
        input integer x,y,enabled;
        integer row,col;reg [4:0] rowbits;
        begin
            is_ink=0;rowbits=0;
            if(enabled)begin
                if(x>=60 && x<90 && y>=60 && y<90 && (x<66||x>=84||y<66||y>=84))is_ink=1;
                if(x>=60 && x<90 && y>=18 && y<60)begin
                    row=(y-18)/6;col=(x-60)/6;
                    case(row)0,2,3,4,5:rowbits=5'b00100;1:rowbits=5'b01100;6:rowbits=5'b01110;endcase
                    if((rowbits>>(4-col))&1)is_ink=1;
                end
            end
        end
    endfunction
    task raster;
        input integer enabled;
        integer x,y;reg [23:0] expected;reg [23:0] previous;
        begin
            for(y=0;y<100;y=y+1)begin
                previous=24'h123456;
                for(x=0;x<128;x=x+1)begin
                    @(negedge clk);de=1;source_rgb={y[7:0],x[7:0],8'h56};
                    @(posedge clk);#1;
                    expected=is_ink(x,y,enabled)?24'h00ff60:source_rgb;
                    if(x>0 && (!ode || rgb!==previous))$fatal(1,"pixel %0d,%0d got %h want %h",x-1,y,rgb,previous);
                    previous=expected;
                    // A new result during active scan must not alter this frame.
                    if(y==40 && x==40)records[0+:40]={9'd20,8'd20,9'd5,8'd5,4'd8,2'b00};
                end
                @(negedge clk);de=0;repeat(4)@(negedge clk);
            end
        end
    endtask
    integer i;
    initial begin
        #50;rst_n=1;enable=1;valid=1;count=1;
        records[0+:40]={9'd10,8'd10,9'd5,8'd5,4'd1,2'b00};sync_frame;sync_frame;raster(1);
        enable=0;sync_frame;raster(0);
        enable=1;count=0;sync_frame;raster(0);
        count=1;valid=0;sync_frame;raster(0);
        // Worst-case 16 full-view boxes exercise the last slot, the final
        // bitmap address, and the build budget before bank publication.
        valid=1;count=16;
        for(i=0;i<16;i=i+1)records[i*40+:40]={9'd0,8'd0,9'd320,8'd180,4'd9,2'b00};
        records[15*40+:40]={9'd100,8'd80,9'd3,8'd3,4'd6,2'b00};
        sync_frame;
        if(d.state!==0 || !d.ready)$fatal(1,"16-box build missed blank budget");
        sync_frame;
        if(d.bitmap[{d.display_bank,16'd0}]!==1 || d.bitmap[{d.display_bank,16'd319}]!==1 ||
           d.bitmap[{d.display_bank,16'd57280}]!==1 || d.bitmap[{d.display_bank,16'd57599}]!==1 ||
           d.bitmap[{d.display_bank,16'd28960}]!==0 || d.bitmap[{d.display_bank,16'd25700}]!==1)
            $fatal(1,"16-box edges/interior/last slot");
        count=0;sync_frame;sync_frame;
        if(d.bitmap[{d.display_bank,16'd57599}]!==0)$fatal(1,"empty group did not clear old edges");
        // A newly committed result during bitmap construction invalidates the
        // partial drawing; the next frame must use only the new sequence.
        count=1;result_generation=16'd10;records[0+:40]={9'd10,8'd10,9'd5,8'd5,4'd2,2'b00};
        @(negedge clk);vs=1;
        @(negedge clk);vs=0;
        repeat(100)@(negedge clk);
        busy=1;result_generation=16'd11;records[0+:40]={9'd30,8'd30,9'd5,8'd5,4'd3,2'b00};
        @(negedge clk);
        busy=0;
        if(d.state!==0 || d.ready || !d.display_valid)
            $fatal(1,"busy did not abort build while preserving the displayed bitmap");
        sync_frame;
        if(!d.display_valid || !d.ready || d.held_generation!=11)
            $fatal(1,"stale build replaced display or new build did not finish");
        sync_frame;
        if(!d.display_valid || d.held_generation!=11 || d.bitmap[{d.display_bank,16'd9630}]!==1)
            $fatal(1,"new sequence was not rebuilt cleanly");
        $display("CNN_OVERLAY_PASS geometry/font/frame-snapshot/disabled/empty/busy/stale");$finish;
    end
endmodule
