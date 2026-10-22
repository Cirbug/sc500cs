`timescale 1ns/1ps
// Real scaler -> denoise -> gamma -> DDR word packer. Only the line RAM
// primitive is modeled; read-first, one-clock read latency matches the IP.
module tb_camera_pixel_stream;
    reg clk=0,rst_n=0,fs=0,v=0;
    reg [95:0] data=0;
    wire sf,sv,sl,df,dv,dl,gf,gv,pf,pv;
    wire [95:0] sd,dd,gd;
    wire [127:0] pd;
    reg [1:0] strength=0;
    always #5 clk=~clk;
    rgb96_downscale_crop scale(.I_clk(clk),.I_rst_n(rst_n),.I_frame_start(fs),
        .I_valid(v),.I_data(data),.O_frame_start(sf),.O_last(sl),.O_valid(sv),.O_data(sd));
    picture_denoise dn(.clk(clk),.rst_n(rst_n),.frame_start(sf),.valid(sv),.last(sl),
        .data(sd),.strength(strength),.out_frame_start(df),.out_valid(dv),.out_last(dl),.out_data(dd));
    rgb96_gamma gamma(.I_clk(clk),.I_rst_n(rst_n),.I_enable(1'b0),.I_gamma_sel(4'd4),.I_bright(2'd1),
        .I_frame_start(df),.I_valid(dv),.I_data(dd),.O_frame_start(gf),.O_valid(gv),.O_data(gd));
    data_96bit_to_128bit packer(clk,rst_n,gf,gv,gd,pf,pv,pd);
    byte expected[$];
    byte want;
    integer in_words=0,out_words=0,lines=0,line_words=0,frame,row,group,b;
    always @(posedge clk) begin
        if(rst_n && sv) begin
            line_words=line_words+1;
            if(sl) begin
                if(line_words!=480) $fatal(1,"scaler line width=%0d",line_words);
                line_words=0;lines=lines+1;
            end
        end
        if(rst_n && gv) begin
            if($isunknown(gd)) $fatal(1,"unknown processed pixels");
            in_words=in_words+1;
            for(integer i=11;i>=0;i=i-1) expected.push_back(gd[i*8+:8]);
        end
        #1;
        if(rst_n && pv) begin
            out_words=out_words+1;
            for(integer i=15;i>=0;i=i-1) begin
                if(expected.size()==0) $fatal(1,"extra packed bytes");
                want=expected.pop_front();
                if(pd[i*8+:8]!==want) $fatal(1,"real chain byte corruption frame=%0d word=%0d byte=%0d",frame,out_words,i);
            end
        end
    end
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        for(frame=0;frame<2;frame=frame+1) begin
            in_words=0;out_words=0;lines=0;line_words=0;strength=frame;
            for(row=0;row<1944;row=row+1) begin
                for(group=0;group<648;group=group+1) begin
                    @(negedge clk);fs=(row==0 && group==0);v=1;
                    for(b=0;b<12;b=b+1) data[b*8+:8]=(row+group+b+frame*31)%240;
                    @(negedge clk);fs=0;v=0;data='hx;
                    // RAW10 unpacker delivers four groups per five input words.
                    if(group%4==3) repeat(2) @(negedge clk);
                end
                repeat(80+frame*40) @(negedge clk);
            end
            repeat(100) @(negedge clk);
            if(lines!=1080 || in_words!=518400 || out_words!=388800 || expected.size()!=0)
                $fatal(1,"incomplete frame=%0d lines=%0d RGB96=%0d DDR128=%0d pending=%0d",frame,lines,in_words,out_words,expected.size());
            $display("PASS real pixel chain frame=%0d: 1080 lines, 518400 RGB96 -> 388800 DDR128, every byte checked",frame);
        end
        $finish;
    end
endmodule

module blk_mem_gen_awb_delay_signal(input clka,clkb,wea,web,
    input [10:0] addra,addrb,input [95:0] dia,dib,output reg [95:0] doa,dob);
    reg [95:0] mem[0:2047];
    always @(posedge clka) begin doa<=mem[addra];if(wea) mem[addra]<=dia;end
    always @(posedge clkb) begin dob<=mem[addrb];if(web) mem[addrb]<=dib;end
endmodule
