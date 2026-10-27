`ifndef SD_RECORDER_V
`define SD_RECORDER_V
`include "video_params.vh"
// REC1: APB SPI master and a dedicated 640x360 RGB888 snapshot in DDR.
// No backpressure is applied to the display. Overflow invalidates the frame.
module sd_recorder #(
    parameter WIDTH=1920, HEIGHT=1080,
    parameter [24:0] BASE=`DDR_SNAPSHOT_BASE_ADDR // byte offset 24 MB
)(
    input wire rst_n, apb_clk, pixel_clk, ddr_clk,
    input wire [7:0] addr,
    input wire sel, enable, write,
    input wire [31:0] wdata,
    output reg [31:0] rdata,
    input wire vs, de,
    input wire [23:0] rgb,
    output reg sd_clk, sd_mosi, sd_cs,
    input wire sd_miso,
    input wire vi_busy, vo_busy, vo_read,
    input wire ready, rd_valid,
    input wire [127:0] rd_data,
    output wire block_video, wr_en, rd_en,
    output wire [24:0] mem_addr,
    output wire [127:0] mem_data,
    output wire video_rd_valid,
    output reg [31:0] ui_status
);
    /* 2026-10-27：照片分辨率 640x360 -> 320x180（降采样从每 3 像素/行 改为每 6）。
     * 快照读是"每次一个 128bit DDR 读"且必须等显示让路，实测 243us/次，
     * 57600 次 = 13 秒；减到 14400 次后约 3.5 秒。 */
    localparam PIXELS=(WIDTH/6)*(HEIGHT/6), WORDS=PIXELS/4;
    wire aw=sel && enable && write;
    reg request, read_request, abort_request;
    reg [15:0] read_index;
    reg capture_busy, capture_ready, read_busy;
    reg [127:0] read_result;
    reg [15:0] divider, spi_timer;
    reg [7:0] tx, rx;
    reg [3:0] edges;
    reg spi_busy;
    reg done1,done2,done3,ra1,ra2,ra3,err1,err2;
    reg done_ddr, read_ack;
    reg [127:0] read_hold;
    reg pixel_error;
    reg [1:0] pixel_error_code;
    reg [1:0] code1,code2;
    reg [17:0] count1,count2;
    reg [28:0] debug1,debug2;
    reg [17:0] pixel_count;
    reg [15:0] written;
    reg [9:0] video_pending;
    reg [2:0] state;
    // Bundled read data is stable before the acknowledgment crosses back.
    always @(posedge apb_clk or negedge rst_n) begin
        if(!rst_n) begin
            request<=0; read_request<=0; abort_request<=0;read_index<=0;
            capture_busy<=0; capture_ready<=0; read_busy<=0; read_result<=0;
            divider<=124; spi_timer<=0; tx<=255; rx<=255; edges<=0;
            sd_clk<=0; sd_mosi<=1; sd_cs<=1; spi_busy<=0; ui_status<=0;
            done1<=0;done2<=0;done3<=0;ra1<=0;ra2<=0;ra3<=0;err1<=0;err2<=0;
            code1<=0;code2<=0;count1<=0;count2<=0;debug1<=0;debug2<=0;
        end else begin
            done1<=done_ddr; done2<=done1; done3<=done2;
            ra1<=read_ack;ra2<=ra1;ra3<=ra2;
            err1<=pixel_error;err2<=err1;
            // Diagnostic buses are interpreted after capture stops.
            code1<=pixel_error_code;code2<=code1;
            count1<=pixel_count;count2<=count1;
            debug1<={video_pending,state,written};debug2<=debug1;
            if(done2!=done3) begin capture_busy<=0;capture_ready<=1;end
            if(ra2!=ra3) begin read_result<=read_hold;read_busy<=0;end
            if(aw) case(addr)
                8'h04: if(wdata[0] && !capture_busy && !read_busy) begin
                    request<=~request; capture_busy<=1;capture_ready<=0;
                end
                // Software may discard/re-arm after a failed capture, but
                // never changes an in-flight DDR read mailbox.
                8'h08: begin capture_busy<=0;capture_ready<=0;abort_request<=~abort_request;end
                8'h20: if(!read_busy && capture_ready && wdata<WORDS) begin
                    read_index<=wdata[15:0]; read_request<=~read_request;read_busy<=1;
                end
                8'h40: if(!spi_busy) divider<=wdata[15:0];
                8'h44: if(!spi_busy) sd_cs<=wdata[0];
                8'h48: if(!spi_busy) begin
                    tx<=wdata[7:0];rx<=0;edges<=0;spi_timer<=divider;
                    sd_mosi<=wdata[7];sd_clk<=0;spi_busy<=1;
                end
                8'h60: ui_status<=wdata;
            endcase
            if(spi_busy) begin
                if(spi_timer!=0) spi_timer<=spi_timer-1'b1;
                else begin
                    spi_timer<=divider; sd_clk<=~sd_clk;
                    if(!sd_clk) rx<={rx[6:0],sd_miso};
                    else begin tx<={tx[6:0],1'b1};sd_mosi<=tx[6];end
                    if(edges==15) begin spi_busy<=0;sd_clk<=0;sd_mosi<=1;end
                    else edges<=edges+1'b1;
                end
            end
        end
    end
    always @* begin
        rdata=0;
        case(addr)
            8'h00:rdata=32'h52454331;
            8'h04:rdata={29'd0,err2,capture_ready,capture_busy};
            8'h0c:rdata=WORDS;
            8'h10:rdata={14'd0,count2};
            8'h14:rdata={3'd0,debug2};
            8'h18:rdata={30'd0,code2};
            8'h1c:rdata=32'h00010003; // DDR command FIFO reset-release acceptance fix
            8'h24:rdata={31'd0,read_busy};
            8'h30:rdata=read_result[31:0];8'h34:rdata=read_result[63:32];
            8'h38:rdata=read_result[95:64];8'h3c:rdata=read_result[127:96];
            8'h40:rdata={16'd0,divider};
            8'h4c:rdata={16'd0,rx,7'd0,spi_busy};
            8'h60:rdata=ui_status;
        endcase
    end

    reg p1,p2,p3,epoch_p,armed,active,vs_d,de_d;
    reg pa1,pa2,pa3,abort_p;
    reg [11:0] x,y;
    reg [2:0] xm,ym;      /* 0..5：每 6 个像素/行取 1 */
    reg [1:0] pack_n;     /* 0..3：4 个像素打包成 128bit */
    reg [127:0] pack;
    reg fifo_push;
    reg [127:0] fifo_in;
    wire fifo_full, fifo_empty;
    wire [127:0] fifo_out;
    reg [3:0] clear_count;
    wire fifo_reset=(!rst_n) || (clear_count!=0);
    always @(posedge pixel_clk or negedge rst_n) begin
        if(!rst_n) begin
            p1<=0;p2<=0;p3<=0;epoch_p<=0;armed<=0;active<=0;
            vs_d<=0;de_d<=0;x<=0;y<=0;xm<=0;ym<=0;pack_n<=0;
            pixel_count<=0;pack<=0;fifo_push<=0;fifo_in<=0;pixel_error<=0;
            pixel_error_code<=0;pa1<=0;pa2<=0;pa3<=0;abort_p<=0;
        end else begin
            p1<=request;p2<=p1;p3<=p2;vs_d<=vs;de_d<=de;fifo_push<=0;
            pa1<=abort_request;pa2<=pa1;pa3<=pa2;
            if(p3!=epoch_p) begin
                epoch_p<=p3;armed<=1;active<=0;pixel_error<=0;pixel_error_code<=0;
            end else if(vs && !vs_d) begin
                x<=0;y<=0;xm<=0;ym<=0;pack_n<=0;pixel_count<=0;
                if(active) begin pixel_error<=1;pixel_error_code<=2;end // short frame
                active<=armed;armed<=0;
            end else begin
                if(!de && de_d) begin x<=0;xm<=0;y<=y+1'b1;ym<=ym==5?0:ym+1'b1;end
                if(de) begin
                    x<=x+1'b1;xm<=xm==5?0:xm+1'b1;
                    if(active && x<WIDTH && y<HEIGHT && xm==0 && ym==0) begin
                        pack<={8'd0,rgb,pack[127:32]};pack_n<=pack_n+1'b1;
                        pixel_count<=pixel_count+1'b1;
                        if(pack_n==3) begin
                            fifo_in<={8'd0,rgb,pack[127:32]};
                            if(fifo_full) begin pixel_error<=1;pixel_error_code<=1;active<=0;end
                            else fifo_push<=1;
                        end
                        if(pixel_count==PIXELS-1) active<=0;
                    end
                end
            end
            if(pa3!=abort_p) begin abort_p<=pa3;active<=0;armed<=0;fifo_push<=0;end
        end
    end
    // Standard Gray-pointer async FIFO. RAM read is registered (one cycle).
    reg [8:0] wp,rp;
    reg [9:0] wb,rb,wg,rg;
    reg [9:0] rg1,rg2,wg1,wg2;
    reg [127:0] fifo_ram[0:511];
    reg [127:0] fifo_q;
    wire pop;
    assign fifo_full=(wg=={~rg2[9:8],rg2[7:0]});
    assign fifo_empty=(rg==wg2);
    assign fifo_out=fifo_q;
    always @(posedge pixel_clk or posedge fifo_reset) begin
        if(fifo_reset) begin wb<=0;wg<=0;rg1<=0;rg2<=0;end
        else begin
            rg1<=rg;rg2<=rg1;
            if(fifo_push && !fifo_full) begin wb<=wb+1'b1;wg<=((wb+1'b1)>>1)^(wb+1'b1);end
        end
    end
    always @(posedge pixel_clk) if(fifo_push && !fifo_full && !fifo_reset) fifo_ram[wb[8:0]]<=fifo_in;
    always @(posedge ddr_clk or posedge fifo_reset) begin
        if(fifo_reset) begin rb<=0;rg<=0;wg1<=0;wg2<=0;end
        else begin
            wg1<=wg;wg2<=wg1;
            if(pop) begin rb<=rb+1'b1;rg<=((rb+1'b1)>>1)^(rb+1'b1);end
        end
    end
    always @(posedge ddr_clk) if(pop) fifo_q<=fifo_ram[rb[8:0]];

    reg d1,d2,d3,epoch_d,r1,r2,r3,read_seen;
    reg [24:0] held_addr;
    reg a1,a2,a3,abort_seen,ed1,ed2,error_seen,capture_live;
    wire cancel_ddr=(a3!=abort_seen) || (ed2 && !error_seen);
    // Ask the existing video masters to finish their burst and refrain from
    // starting another one. Wait for every outstanding video read response.
    wire can_write=capture_live && !ed2 && !cancel_ddr && clear_count==0;
    wire want=(!fifo_empty && written<WORDS && can_write) ||
              ((r3!=read_seen) && state!=4 && !cancel_ddr);
    // Once our read is issued, video requests can follow it in the ordered
    // queue. Do not hold the display blocked while waiting for the response.
    assign block_video=want || (state!=0 && state!=4 && !cancel_ddr);
    assign video_rd_valid=rd_valid && state!=4;
    assign pop=(state==1) && can_write;
    assign wr_en=(state==2) && ready && can_write;
    assign rd_en=(state==3) && ready && !cancel_ddr;
    assign mem_addr=state==2 ? BASE+{written,3'b000} : held_addr;
    assign mem_data=fifo_out;
    always @(posedge ddr_clk or negedge rst_n) begin
        if(!rst_n) begin
            d1<=0;d2<=0;d3<=0;epoch_d<=0;r1<=0;r2<=0;r3<=0;read_seen<=0;
            written<=0;clear_count<=15;state<=0;video_pending<=0;
            held_addr<=BASE;done_ddr<=0;read_ack<=0;read_hold<=0;
            a1<=0;a2<=0;a3<=0;abort_seen<=0;ed1<=0;ed2<=0;error_seen<=0;capture_live<=0;
        end else begin
            d1<=request;d2<=d1;d3<=d2;r1<=read_request;r2<=r1;r3<=r2;
            a1<=abort_request;a2<=a1;a3<=a2;ed1<=pixel_error;ed2<=ed1;
            if(!ed2) error_seen<=0;
            if(clear_count!=0) clear_count<=clear_count-1'b1;
            case({vo_read,video_rd_valid})
                2'b10:video_pending<=video_pending+1'b1;
                2'b01:if(video_pending!=0) video_pending<=video_pending-1'b1;
            endcase
            if(cancel_ddr) begin
                abort_seen<=a3;error_seen<=ed2;capture_live<=0;clear_count<=15;
                // Already-issued reads still own their response. All queued
                // capture writes and not-yet-issued reads can be discarded.
                if(state!=4) begin state<=0;read_seen<=r3;read_ack<=r3;end
            end else if(d3!=epoch_d && state==0) begin
                epoch_d<=d3;written<=0;clear_count<=15;capture_live<=1;
            end else if(clear_count==0) case(state)
                0:if(!vi_busy && !vo_busy) begin
                    // Writes do not consume read responses: there is no
                    // reason to wait for outstanding VIDEO reads to drain.
                    if(!fifo_empty && written<WORDS && can_write) state<=1;
                    else if(r3!=read_seen && video_pending==0) begin
                        held_addr<=BASE+{read_index,3'b000};state<=3;
                    end
                end
                1:state<=2;
                2:if(ready) begin
                    written<=written+1'b1;state<=0;
                    if(written==WORDS-1) done_ddr<=~done_ddr;
                end
                3:if(ready) state<=4;
                4:if(rd_valid) begin
                    read_hold<=rd_data;read_seen<=r3;read_ack<=r3;state<=0;
                end
                default:state<=0;
            endcase
            // A cancelled capture may reset its FIFO while a previously
            // issued mailbox read returns. Never discard that response.
            if(state==4 && rd_valid) begin
                read_hold<=rd_data;read_seen<=r3;read_ack<=r3;state<=0;
            end
        end
    end
endmodule
`endif
