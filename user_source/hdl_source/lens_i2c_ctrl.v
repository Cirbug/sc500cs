// Small write-only I2C controller for the 0x18 lens actuator.
// The existing camera configuration bus remains independent (K3/J3).
module lens_i2c_ctrl #(
    parameter integer CLK_DIV = 16'd499,
    parameter [13:0] INIT_POSITION = 14'd8192
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_cfg_done,
    input  wire        I_cmd_valid,
    input  wire [13:0] I_position,
    output wire        O_scl,
    inout  wire        IO_sda,
    output reg         O_busy,
    output reg         O_init_done,
    output reg         O_error
);

    localparam [3:0] ST_WAIT_CFG = 4'd0;
    localparam [3:0] ST_DELAY    = 4'd1;
    localparam [3:0] ST_REQ      = 4'd2;
    localparam [3:0] ST_WAIT_HI  = 4'd3;
    localparam [3:0] ST_WAIT_LO  = 4'd4;
    localparam [3:0] ST_READY    = 4'd5;

    reg [3:0] state;
    reg [18:0] delay_count;
    reg [13:0] position_latched;
    reg [31:0] wr_data;
    reg [2:0]  wr_count;
    reg [1:0]  tx_kind;
    reg        iic_req;
    reg        active_sent;
    wire       iic_busy;
    wire       iic_error;

    // The uii2c byte order is little-endian in I_wr_data: byte 0 first.
    // The actuator datasheet specifies two separate writes for one position:
    // 0x18,0x00,high-byte followed by 0x18,0x01,low-byte.
    task automatic load_position_high;
        input [13:0] position;
        begin
            wr_data[7:0]   <= 8'h18;
            wr_data[15:8]  <= 8'h00;
            wr_data[23:16] <= {position[13:6]};
            wr_data[31:24] <= 8'd0;
        end
    endtask
    task automatic load_position_low;
        input [13:0] position;
        begin
            wr_data[7:0]   <= 8'h18;
            wr_data[15:8]  <= 8'h01;
            wr_data[23:16] <= {position[5:0], 2'b00};
            wr_data[31:24] <= 8'd0;
        end
    endtask

    uii2c #(
        .WMEN_LEN(4),
        .RMEN_LEN(1),
        .CLK_DIV(CLK_DIV)
    ) u_lens_i2c (
        .I_clk       (I_clk),
        .I_rstn      (I_rst_n),
        .O_iic_scl   (O_scl),
        .IO_iic_sda  (IO_sda),
        .I_wr_data   (wr_data),
        .I_wr_cnt    ({5'd0, wr_count}),
        .O_rd_data   (),
        .I_rd_cnt    (8'd0),
        .I_iic_mode  (1'b0),
        .I_iic_req   (iic_req),
        .O_iic_busy  (iic_busy),
        .O_iic_bus_error(iic_error),
        .IO_iic_sda_dg()
    );

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state          <= ST_WAIT_CFG;
            delay_count    <= 19'd0;
            position_latched <= INIT_POSITION;
            wr_data        <= 32'd0;
            wr_count       <= 3'd0;
            tx_kind        <= 2'd0;
            iic_req        <= 1'b0;
            active_sent    <= 1'b0;
            O_busy         <= 1'b0;
            O_init_done    <= 1'b0;
            O_error        <= 1'b0;
        end else begin
            iic_req <= 1'b0;
            case(state)
                ST_WAIT_CFG: begin
                    O_busy <= 1'b0;
                    if(I_cfg_done) begin
                        // 50 MHz APB clock: 262144 cycles is 5.24 ms.
                        delay_count <= 19'd0;
                        O_busy <= 1'b1;
                        state <= ST_DELAY;
                    end
                end
                ST_DELAY: begin
                    O_busy <= 1'b1;
                    if(delay_count == 19'd262143) begin
                        wr_data[7:0]   <= 8'h18;
                        wr_data[15:8]  <= 8'h02;
                        wr_data[23:16] <= 8'h00;
                        wr_data[31:24] <= 8'h00;
                        wr_count       <= 3'd3;
                        tx_kind        <= 2'd0; // active mode transaction
                        state <= ST_REQ;
                    end else begin
                        delay_count <= delay_count + 1'b1;
                    end
                end
                ST_REQ: begin
                    iic_req <= 1'b1;
                    state <= ST_WAIT_HI;
                end
                ST_WAIT_HI: begin
                    // uii2c samples the request on its divided SCL clock;
                    // keep it asserted until the controller acknowledges it.
                    iic_req <= 1'b1;
                    if(iic_busy)
                        state <= ST_WAIT_LO;
                end
                ST_WAIT_LO: begin
                    if(!iic_busy) begin
                        if(iic_error) begin
                            O_error <= 1'b1;
                            O_busy <= 1'b0;
                            state <= ST_READY;
                        end else if(tx_kind == 2'd0) begin
                            active_sent <= 1'b1;
                            position_latched <= INIT_POSITION;
                            load_position_high(INIT_POSITION);
                            wr_count <= 3'd3;
                            tx_kind <= 2'd1;
                            state <= ST_REQ;
                        end else if(tx_kind == 2'd1) begin
                            load_position_low(position_latched);
                            wr_count <= 3'd3;
                            tx_kind <= 2'd2;
                            state <= ST_REQ;
                        end else begin
                            O_init_done <= 1'b1;
                            O_busy <= 1'b0;
                            state <= ST_READY;
                        end
                    end
                end
                ST_READY: begin
                    O_busy <= 1'b0;
                    if(!O_init_done && !O_error) begin
                        // The position transaction has completed.
                        O_init_done <= 1'b1;
                    end else if(I_cmd_valid && !O_error) begin
                        position_latched <= I_position;
                        load_position_high(I_position);
                        wr_count <= 3'd3;
                        tx_kind <= 2'd1;
                        O_busy <= 1'b1;
                        state <= ST_REQ;
                    end
                end
                default: state <= ST_WAIT_CFG;
            endcase
        end
    end
endmodule
