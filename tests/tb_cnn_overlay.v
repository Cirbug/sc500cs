`timescale 1ns/1ps
module tb_cnn_overlay;
    reg clk=0,rst_n=0,enable=0,valid=0,vs=0,hs=0,de=0;
    reg [671:0] records=0;reg [4:0] count=0;
    reg [23:0] source_rgb=24'h123456;
    wire ovs,ohs,ode;wire [23:0] rgb;
    always #5 clk=~clk;
    cnn_digit_overlay d(.clk(clk),.rst_n(rst_n),.enable(enable),.result_valid(valid),
        .result_count(count),.result_records(records),.vs(vs),.hs(hs),.de(de),.rgb(source_rgb),
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
                    if(y==40 && x==40)records[0+:42]={10'd20,9'd20,10'd5,9'd5,4'd8};
                end
                @(negedge clk);de=0;repeat(4)@(negedge clk);
            end
        end
    endtask
    integer i;
    initial begin
        #50;rst_n=1;enable=1;valid=1;count=1;
        records[0+:42]={10'd10,9'd10,10'd5,9'd5,4'd1};sync_frame;sync_frame;raster(1);
        enable=0;sync_frame;raster(0);
        enable=1;count=0;sync_frame;raster(0);
        count=1;valid=0;sync_frame;raster(0);
        // Worst-case 16 full-view boxes exercise the last slot, the final
        // bitmap address, and the build budget before bank publication.
        valid=1;count=16;
        for(i=0;i<16;i=i+1)records[i*42+:42]={10'd0,9'd0,10'd320,9'd180,4'd9};
        records[15*42+:42]={10'd100,9'd80,10'd3,9'd3,4'd6};
        sync_frame;
        if(d.state!==0 || !d.ready)$fatal(1,"16-box build missed blank budget");
        sync_frame;
        if(d.bitmap[{d.display_bank,16'd0}]!==1 || d.bitmap[{d.display_bank,16'd319}]!==1 ||
           d.bitmap[{d.display_bank,16'd57280}]!==1 || d.bitmap[{d.display_bank,16'd57599}]!==1 ||
           d.bitmap[{d.display_bank,16'd28960}]!==0 || d.bitmap[{d.display_bank,16'd25700}]!==1)
            $fatal(1,"16-box edges/interior/last slot");
        count=0;sync_frame;sync_frame;
        if(d.bitmap[{d.display_bank,16'd57599}]!==0)$fatal(1,"empty group did not clear old edges");
        $display("CNN_OVERLAY_PASS geometry/font/frame-snapshot/disabled/empty/stale");$finish;
    end
endmodule
