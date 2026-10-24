`timescale 1ns/1ps

module tb_eth_udp_result_rx;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg rx_valid = 1'b0;
    reg [7:0] rx_data = 8'd0;
    reg [15:0] rx_len = 16'd0;
    reg [15:0] rx_src_port = 16'd0;
    reg [383:0] response;
    reg [191:0] analysis_result;
    wire shape_valid;
    wire [2:0] shape_type;
    wire [11:0] shape_x0, shape_y0, shape_x1, shape_y1;
    integer i;

    always #5 clk = ~clk;

    eth_udp_result_rx dut (
        .I_clk(clk), .I_reset(rst), .I_dst_clk(clk),
        .I_rx_valid(rx_valid), .I_rx_data(rx_data),
        .I_rx_len(rx_len), .I_rx_src_port(rx_src_port),
        .O_shape_valid(shape_valid), .O_shape_type(shape_type),
        .O_shape_x0(shape_x0), .O_shape_y0(shape_y0),
        .O_shape_x1(shape_x1), .O_shape_y1(shape_y1)
    );

    task send_response;
        input [383:0] packet;
        input [15:0] source_port;
        input [15:0] packet_len;
        begin
            for (i = 0; i < 48; i = i + 1) begin
                @(negedge clk);
                rx_valid = 1'b1;
                rx_data = packet[383-(i*8) -: 8];
                rx_len = packet_len;
                rx_src_port = source_port;
            end
            @(negedge clk);
            rx_valid = 1'b0;
            rx_data = 8'd0;
        end
    endtask

    task wait_result;
        begin repeat (30) @(posedge clk); end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;
        wait_result;

        analysis_result = 192'd0;
        analysis_result[185] = 1'b1;
        analysis_result[178:176] = 3'd3;
        analysis_result[73:64] = 10'd100;
        analysis_result[56:48] = 9'd50;
        analysis_result[41:32] = 10'd200;
        analysis_result[24:16] = 9'd150;
        response = {{32'h5041434b,32'd21,16'd1280,16'd720,
                     16'd1,16'd0,32'd100,32'd2},analysis_result};
        send_response(response,16'd6002,16'd48);
        wait_result;
        if (!shape_valid || shape_type != 3'd3 ||
            shape_x0 != 12'd300 || shape_y0 != 12'd150 ||
            shape_x1 != 12'd602 || shape_y1 != 12'd452)
            $fatal(1,"shape result decode/scale mismatch");

        analysis_result = 192'd0;
        response = {{32'h5041434b,32'd22,16'd1280,16'd720,
                     16'd1,16'd0,32'd101,32'd2},analysis_result};
        send_response(response,16'd6002,16'd48);
        wait_result;
        if (shape_valid)
            $fatal(1,"empty analysis result did not clear shape");

        analysis_result = 192'd0;
        analysis_result[185] = 1'b1;
        analysis_result[178:176] = 3'd2;
        response = {{32'h5041434b,32'd23,16'd1280,16'd720,
                     16'd1,16'd0,32'd102,32'd2},analysis_result};
        send_response(response,16'd6003,16'd48);
        wait_result;
        if (shape_valid)
            $fatal(1,"result from unexpected source port was accepted");

        $display("ETH_UDP_RESULT_RX_TEST_PASS");
        $finish;
    end
endmodule
