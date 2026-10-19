// 230400 individual 3-bit classes, five per 16-bit word. No pixel decimation.
// First 32768 words use all sixteen 32K blocks; remaining words use 9K RAM.
// A frame is immutable from analysis start to completion. Port B clears only
// the visited pixel, preserving the four other classes sharing its word.
module packed_tag_ram640(
 input wclk,we,input [15:0] word_addr,input [2:0] lane,tag,
 input rclk,input [17:0] pixel_addr,input clear,output [2:0] q
);
 reg [11:0] pack;
 wire [15:0] wd={1'b0,tag,pack};
 wire commit=we && lane==4;
 always @(posedge wclk)if(we)pack<={tag,pack[11:3]};
 wire [15:0] ra=pixel_addr/5;
 wire [2:0] rl=pixel_addr%5;
 reg [15:0] ra_q;reg [2:0] rl_q;
 always @(posedge rclk)begin ra_q<=ra;rl_q<=rl;end
 wire [15:0] low_q[0:15];
 reg [15:0] high_q;
 wire [15:0] word_q=ra_q[15]?high_q:low_q[ra_q[14:11]];
 wire [3:0] shift={1'b0,rl_q}*4'd3;
 assign q=word_q>>shift;
 wire [15:0] clear_word=word_q & ~(16'h0007<<shift);
 genvar b;
 generate for(b=0;b<16;b=b+1)begin: banks
`ifdef MODEL_SIM
  reg [15:0] mem[0:2047];reg [15:0] dq;
  assign low_q[b]=dq;
  always @(posedge wclk)if(commit && word_addr[15:11]==b)mem[word_addr[10:0]]<=wd;
  always @(posedge rclk)begin
   if(clear && ra[15:11]==b)mem[ra[10:0]]<=clear_word;
   else dq<=mem[ra[10:0]];
  end
`else
  EG_PHY_BRAM32K #(.MODE("DP16K"),.DATA_WIDTH_A("16"),.DATA_WIDTH_B("16"),
   .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL")) ram(
   .doa(),.dia(wd),.addra(word_addr[10:0]),.bytea(1'b0),.bytewea(1'b0),
   .csa(1'b1),.wea(commit && word_addr[15:11]==b),.clka(wclk),.rsta(1'b0),.ocea(1'b1),
   .dob(low_q[b]),.dib(clear_word),.addrb(ra[10:0]),.byteb(1'b0),.byteweb(1'b0),
   .csb(1'b1),.web(clear && ra[15:11]==b),.clkb(rclk),.rstb(1'b0),.oceb(1'b1));
`endif
 end endgenerate
 (* ram_style="bram" *) reg [15:0] high_mem[0:16383];
 always @(posedge wclk)if(commit && word_addr[15])high_mem[word_addr[13:0]]<=wd;
 always @(posedge rclk)begin
  high_q<=high_mem[ra[13:0]];
  if(clear && ra[15])high_mem[ra[13:0]]<=clear_word;
 end
endmodule
