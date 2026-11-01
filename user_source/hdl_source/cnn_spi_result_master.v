`ifndef CNN_SPI_RESULT_MASTER_V
`define CNN_SPI_RESULT_MASTER_V
// Mode 0, MSB first. Fixed 160-byte DG/1 packet, CRC16 CCITT-FALSE.
// Camera and display never wait for this independent polling engine.
module cnn_spi_result_master #(
    parameter integer CLK_HZ=75000000,
    parameter integer HALF_PERIOD=75,
    parameter integer POLL_CYCLES=7500000,
    parameter integer TIMEOUT_CYCLES=225000000
)(
    input wire clk,rst_n,spi_miso,
    output reg spi_clk,spi_cs_n,spi_mosi,
    output reg result_new,
    output wire result_valid,result_busy,
    output reg [639:0] result_records,
    output reg [4:0] result_count,
    output reg result_overflow,
    output reg [15:0] result_sequence,
    output reg [15:0] result_generation,
    output reg [31:0] result_weight_crc,good_packets,bad_packets
);
    (* async_reg="true" *) reg [1:0] miso_sync;
    reg [31:0] poll_timer,age;
    reg [15:0] divider;
    reg [1:0] state;
    localparam IDLE=0,TRANSFER=1,HOLD=2;
    reg [7:0] byte_index,rx_shift,byte_data,byte_number;
    reg [2:0] bit_index;
    reg byte_valid,start_packet,have_result,receiving;
    reg [4:0] pending_count;
    reg pending_overflow,packet_bad;
    reg [15:0] pending_sequence,crc,received_crc;
    reg [31:0] pending_weight;
    reg [3:0] record_index,field_index;
    reg [8:0] x,w;
    reg [7:0] y,h;
    wire [9:0] right={1'b0,x}+{1'b0,w};
    wire [8:0] bottom={1'b0,y}+{1'b0,h};
    assign result_valid=have_result && age<TIMEOUT_CYCLES;
    assign result_busy=receiving;
    function [15:0] crc_byte;
        input [15:0] c0;input [7:0] data;
        reg [15:0] c;integer k;
        begin c=c0^{data,8'd0};
            for(k=0;k<8;k=k+1)c=c[15]?(c<<1)^16'h1021:c<<1;
            crc_byte=c;
        end
    endfunction
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            miso_sync<=0;spi_clk<=0;spi_cs_n<=1;spi_mosi<=0;
            poll_timer<=0;divider<=0;state<=IDLE;
            byte_index<=0;bit_index<=7;rx_shift<=0;byte_valid<=0;
            byte_data<=0;byte_number<=0;start_packet<=0;
        end else begin
            miso_sync<={miso_sync[0],spi_miso};byte_valid<=0;start_packet<=0;
            case(state)
            IDLE:if(poll_timer==0)begin
                spi_cs_n<=0;spi_clk<=0;spi_mosi<=1; // A5 bit 7
                divider<=HALF_PERIOD-1;byte_index<=0;bit_index<=7;
                rx_shift<=0;start_packet<=1;state<=TRANSFER;
            end else poll_timer<=poll_timer-1'b1;
            TRANSFER:if(divider!=0)divider<=divider-1'b1;
            else begin
                divider<=HALF_PERIOD-1;spi_clk<=~spi_clk;
                if(!spi_clk)begin
                    rx_shift<={rx_shift[6:0],miso_sync[1]};
                    if(bit_index==0)begin
                        byte_valid<=1;byte_data<={rx_shift[6:0],miso_sync[1]};byte_number<=byte_index;
                    end
                end else begin
                    if(bit_index==0)begin
                        spi_mosi<=0;bit_index<=7;
                        if(byte_index==159)state<=HOLD;
                        else byte_index<=byte_index+1'b1;
                    end else begin
                        bit_index<=bit_index-1'b1;
                        spi_mosi<=(byte_index==0)?((8'ha5>>(bit_index-1'b1))&1'b1):1'b0;
                    end
                end
            end
            HOLD:if(divider!=0)divider<=divider-1'b1;
            else begin spi_cs_n<=1;spi_mosi<=0;poll_timer<=POLL_CYCLES-1;state<=IDLE;end
            default:state<=IDLE;
            endcase
        end
    end
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            result_new<=0;have_result<=0;receiving<=0;age<=TIMEOUT_CYCLES;
            result_count<=0;result_overflow<=0;result_sequence<=0;result_generation<=0;
            result_weight_crc<=0;good_packets<=0;bad_packets<=0;
            pending_count<=0;pending_overflow<=0;
            pending_sequence<=0;pending_weight<=0;crc<=16'hffff;received_crc<=0;
            record_index<=0;field_index<=0;packet_bad<=0;x<=0;y<=0;w<=0;h<=0;
        end else begin
            result_new<=0;if(age<TIMEOUT_CYCLES)age<=age+1'b1;
            if(start_packet)begin
                crc<=16'hffff;packet_bad<=0;
                record_index<=0;field_index<=0;
                receiving<=1;result_generation<=result_generation+1'b1;
            end
            if(byte_valid)begin
                if(byte_number<156)crc<=crc_byte(crc,byte_data);
                case(byte_number)
                0:if(byte_data!=8'h44)packet_bad<=1;
                1:if(byte_data!=8'h47)packet_bad<=1;
                2:if(byte_data!=1)packet_bad<=1;
                3:begin pending_overflow<=byte_data[1];if((byte_data&8'hfd)!=1)packet_bad<=1;end
                4:pending_sequence[15:8]<=byte_data;
                5:pending_sequence[7:0]<=byte_data;
                6:begin pending_count<=byte_data[4:0];if(byte_data>16)packet_bad<=1;end
                7:if(byte_data!=0)packet_bad<=1;
                152:pending_weight[31:24]<=byte_data;
                153:pending_weight[23:16]<=byte_data;
                154:pending_weight[15:8]<=byte_data;
                155:pending_weight[7:0]<=byte_data;
                156:received_crc[15:8]<=byte_data;
                157:received_crc[7:0]<=byte_data;
                158:if(byte_data!=13)packet_bad<=1;
                159:begin
                    if(!packet_bad && byte_data==10 && crc==received_crc)begin
                        good_packets<=good_packets+1'b1;
                        receiving<=0;result_generation<=result_generation+1'b1;
                        if(!have_result || pending_sequence!=result_sequence)begin
                            result_count<=pending_count;result_overflow<=pending_overflow;
                            result_sequence<=pending_sequence;result_weight_crc<=pending_weight;
                            result_new<=1;have_result<=1;age<=0;
                        end
                    end else begin
                        bad_packets<=bad_packets+1'b1;receiving<=0;have_result<=0;
                    end
                end
                default:begin
                    if(record_index<pending_count)begin
                        case(field_index)
                        0:begin x[8]<=byte_data[0];if(byte_data>1)packet_bad<=1;end
                        1:x[7:0]<=byte_data;
                        2:if(byte_data!=0)packet_bad<=1;
                        3:y[7:0]<=byte_data;
                        4:begin w[8]<=byte_data[0];if(byte_data>1)packet_bad<=1;end
                        5:w[7:0]<=byte_data;
                        6:if(byte_data!=0)packet_bad<=1;
                        7:h[7:0]<=byte_data;
                        8:begin
                            result_records[record_index*40+:40]<={x,y,w,h,byte_data[3:0],2'b00};
                            if(byte_data>9 || w==0 || h==0 || right>320 || bottom>180)packet_bad<=1;
                        end
                        endcase
                    end
                    if(field_index==8)begin field_index<=0;record_index<=record_index+1'b1;end
                    else field_index<=field_index+1'b1;
                end
                endcase
            end
        end
    end
endmodule
`endif
