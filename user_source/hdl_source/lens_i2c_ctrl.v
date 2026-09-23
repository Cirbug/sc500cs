// Lens-only I2C. Camera keeps its original uii2c instance.
// 7-bit slave 0x0c; wire bytes 0x18 write / 0x19 read.
module lens_i2c_ctrl #(
    parameter integer CLK_DIV=499,
    parameter [13:0] INIT_POSITION=14'd8192,
    parameter integer STARTUP_CYCLES=1000000 // 20 ms at 50 MHz
)(
    input wire I_clk, I_rst_n, I_cfg_done, I_cmd_valid,
    input wire I_retry, I_read_adc,
    input wire [13:0] I_position,
    inout wire O_scl, IO_sda,
    output reg O_busy, O_init_done, O_error,
    output reg [31:0] O_diag, O_tx_count, O_adc_raw, O_adc_count,
    output wire [31:0] O_bus_state
);
    localparam WAIT_CFG=0, DELAY=1, REQUEST=2, WAIT_TX=3, READY=4;
    reg [2:0] state, phase;
    reg [31:0] delay_count;
    reg [13:0] position;
    reg start;
    wire done;
    wire [2:0] ack_mask;
    wire [3:0] fault;
    wire [7:0] nack_byte, rx_data;
    wire [7:0] reg_addr=phase==1 ? 8'h02 : phase==2 ? 8'h00 :
                         phase==3 ? 8'h01 : phase==4 ? 8'h84 : 8'h85;
    wire [7:0] reg_value=phase==1 ? 8'h00 : phase==2 ? position[13:6] :
                          {position[5:0],2'b00};
    lens_i2c_master #(.PERIOD_CYCLES(CLK_DIV+1)) u_bus (
        .clk(I_clk), .rst_n(I_rst_n), .start(start), .read_reg(phase>=4),
        .reg_addr(reg_addr), .reg_value(reg_value), .scl(O_scl), .sda(IO_sda),
        .done(done), .ack_mask(ack_mask), .fault(fault), .nack_byte(nack_byte),
        .rx_data(rx_data), .bus_state(O_bus_state)
    );
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state<=WAIT_CFG; phase<=1; delay_count<=0; position<=INIT_POSITION;
            start<=0; O_busy<=0; O_init_done<=0; O_error<=0;
            O_diag<=0; O_tx_count<=0; O_adc_raw<=0; O_adc_count<=0;
        end else begin
            start<=0;
            case(state)
                WAIT_CFG: if(I_cfg_done) begin
                    O_busy<=1; delay_count<=0; state<=DELAY;
                end
                DELAY: if(delay_count>=STARTUP_CYCLES-1) begin
                    phase<=1; position<=INIT_POSITION; state<=REQUEST;
                end else delay_count<=delay_count+1'b1;
                REQUEST: begin start<=1; state<=WAIT_TX; end
                WAIT_TX: if(done) begin
                    // [23:20] fault; [17] fail; [16] valid; [15:8] NACK byte;
                    // [6:4] phase 1 active, 2/3 position, 4/5 ADC84/ADC85.
                    O_diag<={8'd0,fault,2'd0,(fault!=0),1'b1,nack_byte,
                             1'b0,phase,1'b0,ack_mask};
                    O_tx_count<=O_tx_count+1'b1;
                    if(fault!=0) begin
                        O_error<=1; O_busy<=0; O_adc_raw[16]<=0;
                        O_adc_raw[17]<=1; state<=READY;
                    end else if(phase==5) begin
                        O_adc_raw[15:8]<=rx_data; O_adc_raw[16]<=1;
                        O_adc_raw[17]<=0; O_adc_count<=O_adc_count+1'b1;
                        O_busy<=0; state<=READY;
                    end else begin
                        if(phase==3) O_init_done<=1;
                        if(phase==4) O_adc_raw[7:0]<=rx_data;
                        phase<=phase+1'b1; state<=REQUEST;
                    end
                end
                READY: begin
                    if(I_retry) begin
                        O_error<=0; O_init_done<=0; O_adc_raw<=0;
                        O_busy<=1; delay_count<=0; state<=DELAY;
                    end else if(!O_error && O_init_done && (I_cmd_valid || I_read_adc)) begin
                        position<=I_position; phase<=I_cmd_valid ? 3'd2 : 3'd4;
                        O_adc_raw[16]<=0; O_busy<=1; state<=REQUEST;
                    end
                end
                default: state<=WAIT_CFG;
            endcase
        end
    end
endmodule

// Single input-clock master: open drain SCL/SDA, pad synchronizers,
// bounded clock-stretch wait, immediate STOP on NACK. No blind bus-clear pulses.
module lens_i2c_master #(
    parameter integer PERIOD_CYCLES=500,
    parameter integer TIMEOUT_CYCLES=100000 // 2 ms at 50 MHz
)(
    input wire clk, rst_n, start, read_reg,
    input wire [7:0] reg_addr, reg_value,
    inout wire scl, sda,
    output reg done,
    output reg [2:0] ack_mask,
    output reg [3:0] fault,
    output reg [7:0] nack_byte, rx_data,
    output wire [31:0] bus_state
);
    localparam integer LOW_TICKS=PERIOD_CYCLES*3/5;
    localparam integer HIGH_TICKS=PERIOD_CYCLES-LOW_TICKS;
    localparam IDLE=0, FREE=1, START_HOLD=2, BIT_LOW=3, BIT_RISE=4,
        BIT_HIGH=5, ACK_LOW=6, ACK_RISE=7, ACK_HIGH=8,
        RS_LOW=9, RS_RISE=10, RS_HIGH=11, RS_HOLD=12,
        RX_LOW=13, RX_RISE=14, RX_HIGH=15,
        NACK_LOW=16, NACK_RISE=17, NACK_HIGH=18,
        STOP_LOW=19, STOP_RISE=20, STOP_HIGH=21, STOP_FREE=22, LOW_HOLD=23;
    reg [4:0] state, after_hold;
    reg next_sda_low;
    reg scl_low, sda_low;
    (* async_reg="true" *) reg scl_meta, scl_sync, sda_meta, sda_sync;
    reg [31:0] ticks, watchdog;
    reg [7:0] shift, address_latched, value_latched;
    reg [2:0] bit_index;
    reg [1:0] byte_index;
    reg reading, ack_seen;
    assign scl=scl_low ? 1'b0 : 1'bz;
    assign sda=sda_low ? 1'b0 : 1'bz;
    // [0/1] SCL/SDA pad input; [2/3] master releases SCL/SDA; [12:8] state.
    assign bus_state={19'd0,state,4'd0,!sda_low,!scl_low,sda_sync,scl_sync};
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            scl_meta<=1; scl_sync<=1; sda_meta<=1; sda_sync<=1;
        end else begin
            scl_meta<=scl; scl_sync<=scl_meta;
            sda_meta<=sda; sda_sync<=sda_meta;
        end
    end
    // Keep SDA unchanged briefly AFTER SCL falls, then establish the next bit.
    // This avoids creating false START/STOP edges from pad/output skew.
    task lower_bus;
        input data_low;
        input [4:0] following;
        begin
            scl_low<=1; next_sda_low<=data_low; after_hold<=following;
            ticks<=0; watchdog<=0; state<=LOW_HOLD;
        end
    endtask
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            after_hold<=IDLE; next_sda_low<=0;
            state<=IDLE; scl_low<=0; sda_low<=0; ticks<=0; watchdog<=0;
            done<=0; ack_mask<=0; fault<=0; nack_byte<=0; rx_data<=0;
            shift<=0; address_latched<=0; value_latched<=0; bit_index<=7;
            byte_index<=0; reading<=0; ack_seen<=0;
        end else begin
            done<=0;
            // Watchdog resets on each state transition. A stuck bus releases
            // both master outputs and terminates rather than hanging APB/UI.
            if(state!=IDLE && watchdog>=TIMEOUT_CYCLES-1) begin
                if(fault==0) fault<=!scl_sync ? 4'd2 : 4'd3;
                scl_low<=0; sda_low<=0; done<=1; state<=IDLE;
                watchdog<=0; ticks<=0;
            end else begin
                if(state!=IDLE) watchdog<=watchdog+1'b1;
                case(state)
                    IDLE: if(start) begin
                        reading<=read_reg; address_latched<=reg_addr;
                        value_latched<=reg_value; shift<=8'h18;
                        byte_index<=0; bit_index<=7;
                        ack_mask<=0; fault<=0; nack_byte<=0; rx_data<=0;
                        scl_low<=0; sda_low<=0; ticks<=0; watchdog<=0; state<=FREE;
                    end
                    LOW_HOLD: if(ticks>=LOW_TICKS/4-1) begin
                        sda_low<=next_sda_low; ticks<=ticks+1'b1;
                        watchdog<=0; state<=after_hold;
                    end else ticks<=ticks+1'b1;
                    FREE: if(scl_sync && sda_sync) begin
                        if(ticks>=LOW_TICKS-1) begin
                            sda_low<=1; ticks<=0; watchdog<=0; state<=START_HOLD;
                        end else ticks<=ticks+1'b1;
                    end else ticks<=0;
                    START_HOLD, RS_HOLD: if(ticks>=HIGH_TICKS-1) begin
                        lower_bus(!shift[7],BIT_LOW); bit_index<=7;
                    end else ticks<=ticks+1'b1;
                    BIT_LOW: if(ticks>=LOW_TICKS-1) begin
                        scl_low<=0; ticks<=0; watchdog<=0; state<=BIT_RISE;
                    end else ticks<=ticks+1'b1;
                    BIT_RISE: if(scl_sync) begin ticks<=0; watchdog<=0; state<=BIT_HIGH; end
                    BIT_HIGH: if(ticks>=HIGH_TICKS-1) begin
                        if(bit_index==0) lower_bus(0,ACK_LOW);
                        else begin
                            bit_index<=bit_index-1'b1; shift<={shift[6:0],1'b0};
                            lower_bus(!shift[6],BIT_LOW);
                        end
                    end else ticks<=ticks+1'b1;
                    ACK_LOW: if(ticks>=LOW_TICKS-1) begin
                        scl_low<=0; ticks<=0; watchdog<=0; state<=ACK_RISE;
                    end else ticks<=ticks+1'b1;
                    ACK_RISE: if(scl_sync) begin ticks<=0; watchdog<=0; state<=ACK_HIGH; end
                    ACK_HIGH: begin
                        if(ticks==HIGH_TICKS/2) ack_seen<=!sda_sync;
                        if(ticks>=HIGH_TICKS-1) begin
                            if(!ack_seen) begin
                                fault<=1; nack_byte<={6'd0,byte_index}+1'b1;
                                lower_bus(1,STOP_LOW);
                            end else begin
                                ack_mask[byte_index]<=1;
                                if(byte_index==2) begin
                                    if(reading) begin bit_index<=7; lower_bus(0,RX_LOW); end
                                    else begin lower_bus(1,STOP_LOW); end
                                end else if(byte_index==1 && reading) begin
                                    byte_index<=2; shift<=8'h19; lower_bus(0,RS_LOW);
                                end else begin
                                    byte_index<=byte_index+1'b1; bit_index<=7;
                                    shift<=byte_index==0 ? address_latched : value_latched;
                                    lower_bus(byte_index==0 ? !address_latched[7] : !value_latched[7],BIT_LOW);
                                end
                            end
                        end else ticks<=ticks+1'b1;
                    end
                    RS_LOW: if(ticks>=LOW_TICKS-1) begin
                        scl_low<=0; ticks<=0; watchdog<=0; state<=RS_RISE;
                    end else ticks<=ticks+1'b1;
                    RS_RISE: if(scl_sync) begin ticks<=0; watchdog<=0; state<=RS_HIGH; end
                    RS_HIGH: if(ticks>=HIGH_TICKS-1) begin
                        sda_low<=1; ticks<=0; watchdog<=0; state<=RS_HOLD;
                    end else ticks<=ticks+1'b1;
                    RX_LOW: if(ticks>=LOW_TICKS-1) begin
                        scl_low<=0; ticks<=0; watchdog<=0; state<=RX_RISE;
                    end else ticks<=ticks+1'b1;
                    RX_RISE: if(scl_sync) begin ticks<=0; watchdog<=0; state<=RX_HIGH; end
                    RX_HIGH: begin
                        if(ticks==HIGH_TICKS/2) rx_data<={rx_data[6:0],sda_sync};
                        if(ticks>=HIGH_TICKS-1) begin
                            if(bit_index==0) lower_bus(0,NACK_LOW);
                            else begin bit_index<=bit_index-1'b1; lower_bus(0,RX_LOW); end
                        end else ticks<=ticks+1'b1;
                    end
                    NACK_LOW: if(ticks>=LOW_TICKS-1) begin
                        scl_low<=0; ticks<=0; watchdog<=0; state<=NACK_RISE;
                    end else ticks<=ticks+1'b1;
                    NACK_RISE: if(scl_sync) begin ticks<=0; watchdog<=0; state<=NACK_HIGH; end
                    NACK_HIGH: if(ticks>=HIGH_TICKS-1) begin
                        lower_bus(1,STOP_LOW);
                    end else ticks<=ticks+1'b1;
                    STOP_LOW: if(ticks>=LOW_TICKS-1) begin
                        scl_low<=0; ticks<=0; watchdog<=0; state<=STOP_RISE;
                    end else ticks<=ticks+1'b1;
                    STOP_RISE: if(scl_sync) begin ticks<=0; watchdog<=0; state<=STOP_HIGH; end
                    STOP_HIGH: if(ticks>=HIGH_TICKS-1) begin
                        sda_low<=0; ticks<=0; watchdog<=0; state<=STOP_FREE;
                    end else ticks<=ticks+1'b1;
                    STOP_FREE: if(scl_sync && sda_sync) begin
                        if(ticks>=LOW_TICKS-1) begin
                            ticks<=0; watchdog<=0; done<=1; state<=IDLE;
                        end else ticks<=ticks+1'b1;
                    end else ticks<=0;
                    default: begin scl_low<=0; sda_low<=0; state<=IDLE; end
                endcase
            end
        end
    end
endmodule
