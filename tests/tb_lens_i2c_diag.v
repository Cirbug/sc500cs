`timescale 1ns/1ps
// Independent slave reacts only to pad edges, never to master state.
module lens_test_slave(inout wire scl, sda);
    reg drive_low=0, stretch_low=0, stuck_scl=0, stuck_sda=0;
    reg absent=0, active=0, reading=0, read_finished=0;
    reg [7:0] shift=0, pointer=0, value=0;
    integer bits=0, byte_in_segment=0, total_bytes=0;
    integer nack_at=0, starts=0, stops=0, master_nacks=0, observed_count=0;
    integer read_segments=0;
    reg [7:0] observed[0:255];
    reg stretch_enable=0, stretched=0;
    assign scl=(stretch_low || stuck_scl) ? 1'b0 : 1'bz;
    assign sda=(drive_low || stuck_sda) ? 1'b0 : 1'bz;
    always @(negedge sda) if(scl===1'b1) begin
        if(!active) total_bytes=0;
        active=1; bits=0; byte_in_segment=0; reading=0; read_finished=0;
        starts=starts+1;
    end
    always @(posedge sda) if(scl===1'b1 && active) begin active=0; stops=stops+1; end
    always @(posedge scl) if(active && !absent) begin
        if(reading) begin
            if(bits<8) bits=bits+1;
            else if(!read_finished) begin
                if(sda!==1'b1) $fatal(1,"Master must NACK its final read byte");
                master_nacks=master_nacks+1; read_finished=1;
            end
        end else if(bits<8) begin
            shift={shift[6:0],sda}; bits=bits+1;
            if(bits==8) begin
                observed[observed_count]=shift; observed_count=observed_count+1;
                if(byte_in_segment==0 && shift!=8'h18 && shift!=8'h19)
                    $fatal(1,"Incorrect address byte %h",shift);
                if(byte_in_segment==1) pointer=shift;
            end
        end else begin
            bits=0; total_bytes=total_bytes+1;
            if(byte_in_segment==0 && shift==8'h19 && total_bytes!=nack_at) begin
                reading=1; read_segments=read_segments+1;
                value=pointer==8'h84 ? 8'ha6 : pointer==8'h85 ? 8'h5b : 8'hff;
            end
            byte_in_segment=byte_in_segment+1;
        end
    end
    always @(negedge scl) begin
        if(!active || absent) drive_low=0;
        else if(reading) drive_low=(bits<8) ? !value[7-bits] : 0;
        else drive_low=(bits==8) && (total_bytes+1!=nack_at);
    end
    always @(negedge scl) if(stretch_enable && !stretched && active) begin
        stretched=1; stretch_low=1; #50000; stretch_low=0;
    end
endmodule

module tb_lens_i2c_diag;
    reg clk=0; always #10 clk=~clk;
    reg rst_n=0, cfg=0, cmd=0, retry=0, read_adc=0;
    reg [13:0] position=2228;
    tri1 scl,sda;
    wire busy, initialized, error;
    wire [31:0] diag,count,adc,adc_count,bus_state;
    lens_i2c_ctrl #(.STARTUP_CYCLES(1000)) dut (
        .I_clk(clk),.I_rst_n(rst_n),.I_cfg_done(cfg),.I_cmd_valid(cmd),
        .I_retry(retry),.I_read_adc(read_adc),.I_position(position),
        .O_scl(scl),.IO_sda(sda),.O_busy(busy),.O_init_done(initialized),
        .O_error(error),.O_diag(diag),.O_tx_count(count),.O_adc_raw(adc),
        .O_adc_count(adc_count),.O_bus_state(bus_state)
    );
    lens_test_slave slave(scl,sda);
    task wait_idle;
        integer i;
        begin : waiting
            for(i=0;i<600000;i=i+1) begin
                @(negedge clk);
                if(!busy && (initialized || error)) disable waiting;
            end
            $fatal(1,"Timeout waiting for lens");
        end
    endtask
    task request_retry;
        begin
            @(negedge clk); retry=1;
            @(negedge clk); retry=0;
            repeat(4) @(negedge clk); wait_idle();
        end
    endtask
    task check_byte(input integer index,input [7:0] expected);
        if(slave.observed[index]!==expected)
            $fatal(1,"byte[%0d]=%h expected %h",index,slave.observed[index],expected);
    endtask
    integer before_count;
    initial begin
        repeat(10) @(negedge clk); rst_n=1; cfg=1;
        wait_idle();
        if(error || !initialized || count!=5 || adc!==32'h00015ba6 || adc_count!=1)
            $fatal(1,"Initialization/read failed: diag=%h adc=%h count=%d",diag,adc,count);
        if(slave.starts!=7 || slave.stops!=5 || slave.master_nacks!=2)
            $fatal(1,"Missing repeated START or final NACK: start=%0d stop=%0d nack=%0d",slave.starts,slave.stops,slave.master_nacks);
        check_byte(0,'h18); check_byte(1,'h02); check_byte(2,'h00);
        check_byte(3,'h18); check_byte(4,'h00); check_byte(5,'h80);
        check_byte(6,'h18); check_byte(7,'h01); check_byte(8,'h00);
        check_byte(9,'h18); check_byte(10,'h84); check_byte(11,'h19);
        check_byte(12,'h18); check_byte(13,'h85); check_byte(14,'h19);
        $display("PASS: initialization, 0x84/85 reads, repeated START, master NACK");
        @(negedge clk); cmd=1;
        @(negedge clk); cmd=0;
        repeat(4) @(negedge clk); wait_idle();
        check_byte(15,'h18); check_byte(16,'h00); check_byte(17,'h22);
        check_byte(18,'h18); check_byte(19,'h01); check_byte(20,'hd0);
        if(error || count!=9 || adc_count!=2) $fatal(1,"position command/readback failed");
        $display("PASS: position 2228 wire bytes 22/D0 and ADC pair refresh");
        slave.nack_at=3;
        @(negedge clk); read_adc=1;
        @(negedge clk); read_adc=0;
        repeat(4) @(negedge clk); wait_idle();
        if(!error || !initialized || diag[6:4]!=4 || diag[15:8]!=3 ||
           diag[2:0]!=3 || adc[16] || adc_count!=2)
            $fatal(1,"Read-address NACK must invalidate ADC and retain initialized flag");
        slave.nack_at=0; request_retry();
        if(error || !adc[16]) $fatal(1,"Recovery from read NACK failed");
        $display("PASS: read-address NACK invalidates ADC pair; retry recovers");
        slave.absent=1; request_retry();
        if(!error || initialized || diag[23:20]!=1 || diag[15:8]!=1 || adc[16])
            $fatal(1,"Absent slave diagnostic wrong: %h",diag);
        before_count=count;
        repeat(5000) @(negedge clk);
        if(count!=before_count) $fatal(1,"Unexpected automatic retries");
        slave.absent=0; request_retry();
        if(error || !initialized || !adc[16]) $fatal(1,"Retry failed");
        $display("PASS: missing slave => ADDRESS NACK; explicit retry recovers without FPGA reset");
        slave.stuck_sda=1; request_retry();
        if(!error || diag[23:20]!=3 || adc[16]) $fatal(1,"SDA low not diagnosed %h",diag);
        slave.stuck_sda=0; slave.active=0; request_retry();
        if(error) $fatal(1,"SDA release retry failed");
        slave.stuck_scl=1; request_retry();
        if(!error || diag[23:20]!=2 || adc[16]) $fatal(1,"SCL low not diagnosed %h",diag);
        slave.stuck_scl=0; slave.active=0; request_retry();
        if(error) $fatal(1,"SCL release retry failed");
        $display("PASS: stuck SDA / stuck SCL timeout and release/retry");
        $finish;
    end
    initial begin #100000000; $fatal(1,"Global timeout"); end
endmodule

module tb_lens_i2c_master #(parameter integer PERIOD=500);
    reg clk=0; always #10 clk=~clk;
    reg rst_n=0,start=0,read_reg=0;
    reg [7:0] reg_addr=8'h84,reg_value=8'h22;
    tri1 scl,sda;
    wire done; wire [2:0] ack; wire [3:0] fault;
    wire [7:0] nack,data; wire [31:0] bus_state;
    lens_i2c_master #(.PERIOD_CYCLES(PERIOD),.TIMEOUT_CYCLES(5000)) dut(
        .clk(clk),.rst_n(rst_n),.start(start),.read_reg(read_reg),
        .reg_addr(reg_addr),.reg_value(reg_value),.scl(scl),.sda(sda),
        .done(done),.ack_mask(ack),.fault(fault),.nack_byte(nack),
        .rx_data(data),.bus_state(bus_state)
    );
    lens_test_slave slave(scl,sda);
    task run;
        integer i;
        begin : transaction
            @(negedge clk); start=1;
            @(negedge clk); start=0;
            for(i=0;i<60000;i=i+1) begin
                @(negedge clk);
                if(done) disable transaction;
            end
            $fatal(1,"Transaction timeout");
        end
    endtask
    integer b, mode, previous_bytes;
    initial begin
        repeat(10) @(negedge clk); rst_n=1;
        for(mode=0;mode<2;mode=mode+1) begin
            read_reg=mode;
            for(b=1;b<=3;b=b+1) begin
                slave.nack_at=b; previous_bytes=slave.observed_count; run();
                if(fault!=1 || nack!=b || ack!=((1<<(b-1))-1))
                    $fatal(1,"NACK test mode=%d byte=%d ack=%h fault=%h",mode,b,ack,fault);
                if(slave.observed_count-previous_bytes!=b)
                    $fatal(1,"Master sent more bytes after NACK");
            end
        end
        $display("PASS: immediate stop on each of 3 NACK positions, write and combined read");
        slave.nack_at=0; slave.stretch_enable=1; read_reg=1; run();
        if(fault || data!=8'ha6 || ack!=7 || !slave.stretched)
            $fatal(1,"Clock stretching/read failed: %h %h",fault,data);
        $display("PASS: 50us external clock stretch, open drain, read value A6");
        $finish;
    end
    initial begin #20000000; $fatal(1,"Global timeout"); end
endmodule

