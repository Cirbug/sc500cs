`timescale 1ns/1ps
module tb_cnn_spi_link;
    reg aclk=0,bclk=0,rst_n=0;
    always #8.5 aclk=~aclk;
    always #5 bclk=~bclk;
    wire sclk,cs_n,mosi,miso_raw;
    reg corrupt=0,disconnect=0,wrong_command=0;
    // Corrupt one CRC-covered weight bit, keeping all packet semantics valid.
    wire corrupt_bit=corrupt && a.byte_index==155 && a.bit_index==3;
    wire miso=disconnect?1'b0:(miso_raw^corrupt_bit);
    reg digit_done=0,frame_done=0;
    reg [9:0] x=0,w=0;reg [8:0] y=0,h=0;
    reg [3:0] cls=0;reg [4:0] n=0;
    wire result_new,result_valid,result_busy,ov;
    wire [639:0] records;wire [4:0] count;
    wire [15:0] seq;wire [31:0] weight,good,bad;
    cnn_spi_result_slave b(.clk(bclk),.rst_n(rst_n),.spi_clk(sclk),.spi_cs_n(cs_n),.spi_mosi(mosi^wrong_command),.spi_miso(miso_raw),
        .digit_done(digit_done),.frame_done(frame_done),.digit_x(x),.digit_y(y),.digit_w(w),.digit_h(h),
        .digit_class(cls),.frame_count(n),.weight_crc(32'heec8e020));
    cnn_spi_result_master #(.HALF_PERIOD(8),.POLL_CYCLES(400),.TIMEOUT_CYCLES(100000)) a(
        .clk(aclk),.rst_n(rst_n),.spi_miso(miso),.spi_clk(sclk),.spi_cs_n(cs_n),.spi_mosi(mosi),
        .result_new(result_new),.result_valid(result_valid),.result_busy(result_busy),
        .result_records(records),.result_count(count),
        .result_overflow(ov),.result_sequence(seq),.result_weight_crc(weight),.good_packets(good),.bad_packets(bad));
    task emit;
        input integer total;
        integer i;
        begin
            for(i=0;i<total;i=i+1)begin
                @(negedge bclk);digit_done=1;x=i*18;y=i*10;w=10;h=12;cls=i%10;
                @(negedge bclk);digit_done=0;
            end
            @(negedge bclk);frame_done=1;n=total;
            @(negedge bclk);frame_done=0;
        end
    endtask
    task check;
        input integer expect_seq,expect_count,expect_ov;
        integer i;
        begin
            wait(result_new);#1;
            if(seq!==expect_seq || count!==expect_count || ov!==expect_ov || weight!==32'heec8e020 || !result_valid)
                $fatal(1,"header seq=%d count=%d ov=%d weight=%h",seq,count,ov,weight);
            for(i=0;i<expect_count;i=i+1)begin
                if(records[i*40+31+:9]!==i*18 || records[i*40+23+:8]!==i*10 ||
                   records[i*40+14+:9]!==10 || records[i*40+6+:8]!==12 || records[i*40+2+:4]!==i%10 ||
                   records[i*40+:2]!==0)
                    $fatal(1,"record %d mismatch %h",i,records[i*40+:40]);
            end
            $display("PASS seq=%d count=%d overflow=%d",seq,count,ov);
            @(negedge aclk);
        end
    endtask
    integer old_bad,k;reg [15:0] old_seq,old_generation,crc_a,crc_b;
    reg [71:0] crc_vector="123456789";
    initial begin
        crc_a=16'hffff;crc_b=16'hffff;
        for(k=8;k>=0;k=k-1)begin
            crc_a=a.crc_byte(crc_a,crc_vector[k*8+:8]);
            crc_b=b.crc_byte(crc_b,crc_vector[k*8+:8]);
        end
        if(crc_a!==16'h29b1 || crc_b!==16'h29b1)$fatal(1,"CRC standard vector");
        #100;rst_n=1;
        emit(1);check(1,1,0);
        // Rebuild while an old packet is being read: CRC and bank must remain coherent.
        wait(cs_n);wait(!cs_n);#50000;
        if(!result_valid||!result_busy)$fatal(1,"receive busy/last result state mismatch");
        emit(16);check(2,16,0);
        emit(0);check(3,0,0);
        emit(17);check(4,16,1);
        // Disallow malformed coordinates even if transport CRC is correct.
        @(negedge bclk);digit_done=1;x=319;y=0;w=10;h=12;cls=4;
        @(negedge bclk);digit_done=0;frame_done=1;n=1;
        @(negedge bclk);frame_done=0;
        old_bad=bad;repeat(55000)@(posedge aclk);
        if(bad<=old_bad || seq!=4)$fatal(1,"malformed record accepted");
        emit(1);check(6,1,0);
        // A CRC-only error must not publish a new result.
        wait(cs_n);corrupt=1;old_bad=bad;old_seq=seq;old_generation=a.result_generation;
        emit(2);repeat(55000)@(posedge aclk);
        if(bad<=old_bad || seq!=old_seq || result_valid || a.result_generation==old_generation)
            $fatal(1,"corrupt packet accepted or cache remained exposed");
        corrupt=0;check(7,2,0);
        wait(cs_n);wrong_command=1;old_bad=bad;old_seq=seq;
        emit(1);repeat(55000)@(posedge aclk);
        if(bad<=old_bad || seq!=old_seq)$fatal(1,"wrong command accepted");
        wrong_command=0;check(8,1,0);
        // Repeated polls of a stale sequence must not keep boxes alive forever.
        repeat(110000)@(posedge aclk);
        if(result_valid)$fatal(1,"duplicate sequence reset watchdog");
        emit(1);check(9,1,0);
        wait(cs_n);disconnect=1;repeat(110000)@(posedge aclk);
        if(result_valid)$fatal(1,"disconnect watchdog");
        disconnect=0;emit(0);check(10,0,0);
        @(negedge bclk);b.frame_sequence=16'hfffe;
        emit(1);check(65535,1,0);emit(0);check(0,0,0);
        // Digit and frame completion may coincide on the detector interface.
        @(negedge bclk);digit_done=1;frame_done=1;x=0;y=0;w=10;h=12;cls=0;n=1;
        @(negedge bclk);digit_done=0;frame_done=0;check(1,1,0);
        // Reset in the middle of an SPI transaction, then recover cleanly.
        wait(!cs_n);#1234;rst_n=0;#100;rst_n=1;emit(1);check(1,1,0);
        $display("CNN_SPI_LINK_PASS good=%0d bad=%0d",good,bad);$finish;
    end
    initial begin #30000000;$fatal(1,"SPI simulation timeout");end
endmodule
