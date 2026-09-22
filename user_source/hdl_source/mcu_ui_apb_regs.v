// RISC-V APB slave for the camera menu and physical keys.
// APB addresses are byte offsets; the CPU-side high base address is kept in
// the application as UI_APB_BASE because it is device/project dependent.
module mcu_ui_apb_regs #(
    parameter [15:0] AE_MIN  = 16'd3,
    parameter [15:0] AE_MAX  = 16'd5990,
    parameter [15:0] AE_INIT = 16'd2246,
    parameter [15:0] AG_MIN  = 16'd16,
    parameter [15:0] AG_MAX  = 16'd143,
    parameter [15:0] AG_INIT = 16'd80
)(
    input  wire        I_clk,
    input  wire        I_rst,
    input  wire [3:0]  I_button,
    input  wire        I_usb_int_n,
    output reg         O_usb_res_n,
    output reg         O_usb_spi_enable,
    input  wire [19:0] I_paddr,
    input  wire        I_psel,
    input  wire        I_penable,
    input  wire        I_pwrite,
    input  wire [31:0] I_pwdata,
    input  wire [3:0]  I_pstrobe,
    output reg  [31:0] O_prdata,
    output wire        O_pready,
    output wire        O_pslverr,
    output reg         O_menu_enable,
    output reg         O_edit_enable,
    output reg         O_info_enable,
    output reg  [1:0]  O_menu_index,
    output reg  [15:0] O_exposure,
    output reg  [15:0] O_gain,
    input  wire        I_lens_busy,
    input  wire        I_lens_init_done,
    input  wire        I_lens_error,
    input  wire [31:0] I_focus_metric,
    output reg         O_lens_cmd,
    output reg  [13:0] O_lens_position
);

    localparam [31:0] ID_VALUE = 32'h55494D55; // "UIMU"
    wire apb_write = I_psel && I_penable && I_pwrite;
    wire apb_read  = I_psel && I_penable && !I_pwrite;
    assign O_pready = 1'b1;
    assign O_pslverr = 1'b0;

    // key_remove_shakes emits one clock pulse for each active-low press.
    wire [3:0] key_pulse;
    genvar k;
    generate
        for(k = 0; k < 4; k = k + 1) begin : g_key
            key_remove_shakes u_key (
                .I_clk          (I_clk),
                .I_rst_n        (~I_rst),
                .I_key_in       (I_button[k]),
                .O_key_trig_out (key_pulse[k])
            );
        end
    endgenerate

    reg [3:0] key_event;
    // MAX3421E INT is asynchronous to APB; poll the synchronized pin level.
    (* async_reg = "true" *) reg usb_int_meta;
    (* async_reg = "true" *) reg usb_int_sync;
    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst) begin
            usb_int_meta <= 1'b1;
            usb_int_sync <= 1'b1;
        end else begin
            usb_int_meta <= I_usb_int_n;
            usb_int_sync <= usb_int_meta;
        end
    end

    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst) begin
            O_usb_res_n <= 1'b0;
            O_usb_spi_enable <= 1'b0;
            key_event    <= 4'd0;
            O_menu_enable <= 1'b0;
            O_edit_enable <= 1'b0;
            O_info_enable <= 1'b0;
            O_menu_index  <= 2'd0;
            O_exposure    <= AE_INIT;
            O_gain        <= AG_INIT;
            O_lens_cmd    <= 1'b0;
            O_lens_position <= 14'd8192;
        end else begin
            O_lens_cmd <= 1'b0;
            // Preserve a press arriving in the same cycle that software clears
            // an older event.  New events have priority over write-one-to-clear.
            if(apb_write && (I_paddr[7:0] == 8'h04))
                key_event <= (key_event & ~I_pwdata[3:0]) | key_pulse;
            else
                key_event <= key_event | key_pulse;
            if(apb_write) begin
                case(I_paddr[7:0])
                    8'h04: begin end
                    8'h08: begin
                        O_menu_enable <= I_pwdata[0];
                        O_edit_enable <= I_pwdata[1];
                        O_info_enable <= I_pwdata[2];
                    end
                    8'h0c: O_menu_index <= (I_pwdata[1:0] > 2'd3) ? 2'd3 : I_pwdata[1:0];
                    8'h10: O_exposure <= (I_pwdata[15:0] < AE_MIN) ? AE_MIN :
                                           ((I_pwdata[15:0] > AE_MAX) ? AE_MAX : I_pwdata[15:0]);
                    8'h14: O_gain <= (I_pwdata[15:0] < AG_MIN) ? AG_MIN :
                                       ((I_pwdata[15:0] > AG_MAX) ? AG_MAX : I_pwdata[15:0]);
                    // 0x20: bit0 releases reset; bit1 enables external SPI.
                    8'h20: if(I_pstrobe[0]) begin
                        O_usb_res_n <= I_pwdata[0];
                        O_usb_spi_enable <= I_pwdata[1];
                    end
                    8'h28: if(I_pstrobe[0])
                        O_lens_position <= (I_pwdata[13:0] > 14'd16383) ? 14'd16383 : I_pwdata[13:0];
                    // bit0: issue one position transaction to the lens actuator.
                    8'h2c: if(I_pstrobe[0] && I_pwdata[0])
                        O_lens_cmd <= 1'b1;
                    default: begin end
                endcase
            end
        end
    end

    always @* begin
        O_prdata = 32'd0;
        if(apb_read) begin
            case(I_paddr[7:0])
                8'h00: O_prdata = ID_VALUE;
                8'h04: O_prdata = {28'd0, key_event};
                8'h08: O_prdata = {29'd0, O_info_enable, O_edit_enable, O_menu_enable};
                8'h0c: O_prdata = {30'd0, O_menu_index};
                8'h10: O_prdata = {16'd0, O_exposure};
                8'h14: O_prdata = {16'd0, O_gain};
                8'h18: O_prdata = 32'h0001081e; // Full sensor input, HDMI 1080p30
                8'h1c: O_prdata = 32'h4d415831; // "MAX1": USB extension present
                8'h20: O_prdata = {30'd0, O_usb_spi_enable, O_usb_res_n};
                8'h24: O_prdata = {29'd0, O_usb_spi_enable, O_usb_res_n, usb_int_sync};
                8'h28: O_prdata = {18'd0, O_lens_position};
                8'h30: O_prdata = {29'd0, I_lens_error, I_lens_init_done, I_lens_busy};
                8'h34: O_prdata = I_focus_metric;
                default: O_prdata = 32'd0;
            endcase
        end
    end
endmodule
