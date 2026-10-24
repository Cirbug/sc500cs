`timescale 1ns/1ps

// Minimal stand-ins for vendor/ICMP blocks. This test exercises only the
// one-cycle UDP request handshake in uiip_tx.
module PH1P_LOGIC_SHIFTER #(
    parameter DATA_WIDTH = 8,
    parameter DATA_DEPTH = 8,
    parameter INIT_FILE = "NONE",
    parameter SHIFT_TYPE = "FIXED"
) (
    input  wire [0:0] depth,
    output wire [DATA_WIDTH-1:0] dataout,
    input  wire clk,
    input  wire en,
    input  wire [DATA_WIDTH-1:0] datain
);
    assign dataout = {DATA_WIDTH{1'b0}};
endmodule

module uiicmp_pkg_tx (
    input wire I_clk,
    input wire I_reset,
    input wire I_icmp_req_en,
    input wire [15:0] I_icmp_req_id,
    input wire [15:0] I_icmp_req_sq_num,
    input wire [15:0] I_icmp_req_checksum,
    input wire [31:0] I_icmp_req_ip_addr,
    input wire [7:0] I_icmp_ping_echo_data,
    input wire [9:0] I_icmp_ping_echo_data_len,
    output wire O_icmp_ping_echo_ren,
    input wire I_icmp_pkg_busy,
    output wire O_icmp_pkg_req,
    output wire O_icmp_pkg_valid,
    output wire [7:0] O_icmp_pkg_data,
    output wire [9:0] O_icmp_pkg_data_len,
    output wire [31:0] O_icmp_pkg_ip_addr
);
    assign O_icmp_ping_echo_ren = 1'b0;
    assign O_icmp_pkg_req = 1'b0;
    assign O_icmp_pkg_valid = 1'b0;
    assign O_icmp_pkg_data = 8'd0;
    assign O_icmp_pkg_data_len = 10'd0;
    assign O_icmp_pkg_ip_addr = 32'd0;
endmodule

module tb_uiip_tx_request_hold;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg reset = 1'b1;
    reg ip_busy = 1'b0;
    reg udp_req = 1'b0;
    wire udp_busy;
    wire ip_req;
    wire ip_valid;
    wire [7:0] ip_data;
    wire [31:0] ip_addr;
    wire icmp_ren;

    uiip_tx dut (
        .I_ip_local_addr(32'hc0a8320a),
        .I_ip_dest_addr(32'hc0a83214),
        .I_reset(reset),
        .I_ip_clk(clk),
        .O_ip_udp_tbusy(udp_busy),
        .I_ip_udp_treq(udp_req),
        .I_ip_udp_tvalid(1'b0),
        .I_ip_udp_tdata(8'd0),
        .I_ip_udp_tdata_len(16'd1472),
        .I_ip_tbusy(ip_busy),
        .O_ip_treq(ip_req),
        .O_ip_tvalid(ip_valid),
        .O_ip_tdata(ip_data),
        .O_ip_taddr(ip_addr),
        .I_icmp_req_en(1'b0),
        .I_icmp_req_id(16'd0),
        .I_icmp_req_sq_num(16'd0),
        .I_icmp_req_checksum(16'd0),
        .I_icmp_req_ip_addr(32'd0),
        .I_icmp_ping_echo_data(8'd0),
        .I_icmp_ping_echo_data_len(10'd0),
        .O_icmp_ping_echo_ren(icmp_ren)
    );

    task tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        repeat (3) tick();
        @(negedge clk);
        reset = 1'b0;
        ip_busy = 1'b1;
        udp_req = 1'b1;
        tick();

        @(negedge clk);
        udp_req = 1'b0;
        tick();
        if (ip_req !== 1'b0)
            $fatal(1, "IP request must wait while the shared IP sender is busy");

        @(negedge clk);
        ip_busy = 1'b0;
        tick();
        if (ip_req !== 1'b1)
            $fatal(1, "one-cycle UDP request was lost instead of being held");

        @(negedge clk);
        ip_busy = 1'b1;
        tick();
        if (udp_busy !== 1'b1 || ip_req !== 1'b0)
            $fatal(1, "UDP sender did not receive the downstream busy acknowledgement");

        $display("PASS: uiip_tx retains a UDP request until the IP sender becomes idle");
        $finish;
    end
endmodule
