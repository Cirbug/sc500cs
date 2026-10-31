// 480x270 RGB565 preview for the EG4D20 slave board / B relay board.
//
// ===== 格式 =====
//   输出：480 x 270，RGB565（每像素 16 位，高字节先发）
//   每个 16 位字装 **1 个** 像素（与旧版"1 字 2 像素灰度"不同）
//   每帧 = 480*270 = 129600 个 16 位字 = 259200 字节
//   分块：178 块 x 1456B + 末块 32B = 179 块
//
// ===== 降采样 =====
//   1920x1080 每 4x4 邻域取平均 -> 480x270
//   R/G/B 三通道分别求和再除 16（四舍五入），然后压成 RGB565：{R[7:3],G[7:2],B[7:3]}
//
// ===== 实现 =====
//   与灰度版同结构：双 bank 列累加器 + 8KB 环形缓冲 + 灰码指针跨时钟域。
//   累加器每列存 3 通道和：R/G/B 各 12 位（4 行 x 4 像素 x 255 = 4080），共 36 位。
//   一个 4 行带结束时换 bank，并把刚结束那一带的 480 列读出来 >> 4、打包、写入环形缓冲。
module preview_capture_bin #(parameter W=1920,H=1080,STEP=4)(
 input pclk,nclk,rst_n,vs,de,input [23:0] rgb,
 input release_frame,consume_chunk,input [17:0] rd_addr,output reg [15:0] rd_data,
 output ready,chunk_ready,aborted
);
 localparam OW=W/STEP;                 // 480
 localparam OH=H/STEP;                 // 270
 localparam PIX=OW*OH;                 // 129600 像素
 localparam SIZE=PIX;                  // 每字 1 像素
 localparam COUNT_W=$clog2(SIZE+1);
 localparam X_W=$clog2(W+1), Y_W=$clog2(H+1);
 localparam ROWSUM_W=10;               // 4*255=1020
 localparam ACC_W=12;                  // 16*255=4080
 localparam [COUNT_W-1:0] CHUNK_WORDS=728;

 reg [15:0] mem[0:4095];               // 8 KiB 环形缓冲
 reg [3*ACC_W-1:0] accA[0:OW-1], accB[0:OW-1];
 reg [3*ACC_W-1:0] accA_q,accB_q;
 reg [8:0] accA_rd_addr,accB_rd_addr;
 reg accA_en,accB_en,accA_we,accB_we;
 reg [3*ACC_W-1:0] accA_din,accB_din;
 reg pendingA,pendingB;
 reg [8:0] pending_addrA,pending_addrB;
 reg [3*ACC_W-1:0] pending_addA,pending_addB;

 reg pub,rel,active,bad,finished,vd,dd;
 reg [X_W-1:0] x;
 reg [Y_W-1:0] y;
 reg [2:0]  xm,ym;
 reg [8:0]  col;
 reg [3*ACC_W-1:0] rowsum;   // 3 ??,??? 12 ???
 reg [8:0]  ro_cnt;
 reg [8:0]  ro_didx;
 reg        ro_dvalid;
 reg        ro_run;
 reg        bank;
 reg [COUNT_W-1:0] count,committed,reclaimed,wgray,rgray;
 (* ASYNC_REG="TRUE" *) reg rel1,rel2,pub1,pub2,bad1,bad2,fin1,fin2;
 (* ASYNC_REG="TRUE" *) reg [COUNT_W-1:0] wg1,wg2,rg1,rg2;
 function [COUNT_W-1:0] ungray;
  input [COUNT_W-1:0] g;
  integer i;
  begin
   ungray[COUNT_W-1]=g[COUNT_W-1];
   for(i=COUNT_W-2;i>=0;i=i-1)ungray[i]=ungray[i+1]^g[i];
  end
 endfunction
 wire [COUNT_W-1:0] available=ungray(wg2),readback=ungray(rg2);
 wire [COUNT_W-1:0] count_next=count+1'b1;
 wire [COUNT_W-1:0] reclaimed_next=reclaimed+1'b1;
 wire [COUNT_W-1:0] remaining_words=SIZE-committed;
 wire [COUNT_W-1:0] next_chunk_words=(remaining_words>CHUNK_WORDS)?CHUNK_WORDS:remaining_words;
 assign aborted=pub2!=rel && bad2;
 assign ready=pub2!=rel && (available>=CHUNK_WORDS || bad2);
 assign chunk_ready=pub2!=rel && !bad2 && next_chunk_words!=0 &&
                     available>=committed+next_chunk_words &&
                     (committed+next_chunk_words<SIZE || fin2);

 // 当前像素压成 3x10 位：{B,G,R}
 wire [3*ACC_W-1:0] pix3 = {4'b0,rgb[7:0], 4'b0,rgb[15:8], 4'b0,rgb[23:16]}; // 12 ?????

 // 上一带的读出
 wire [3*ACC_W-1:0] ro_val = bank ? accA_q : accB_q;
 wire [7:0] ro_r = ro_val[11:0]  >> 4;     // 0..255
 wire [7:0] ro_g = ro_val[23:12] >> 4;
 wire [7:0] ro_b = ro_val[35:24] >> 4;
 wire [15:0] ro_word = {ro_r[7:3], ro_g[7:2], ro_b[7:3]};

 wire sample_valid=active && de && x<W && y<H && !bad;
 wire sample_group_end=sample_valid && xm==STEP-1;
 wire [3*ACC_W-1:0] sample_add=rowsum+pix3;
 wire eventA=sample_group_end && !bank;
 wire eventB=sample_group_end && bank;

 always @* begin
  accA_rd_addr=0;accA_en=0;accA_we=0;accA_din=0;
  if(pendingA)begin
   accA_rd_addr=pending_addrA;accA_en=1;accA_we=1;accA_din=accA_q+pending_addA;
  end else if(eventA)begin
   accA_rd_addr=col;accA_en=1;
   if(ym==0)begin accA_we=1;accA_din=sample_add;end
  end else if(ro_run && bank)begin
   accA_rd_addr=ro_cnt;accA_en=1;
  end

  accB_rd_addr=0;accB_en=0;accB_we=0;accB_din=0;
  if(pendingB)begin
   accB_rd_addr=pending_addrB;accB_en=1;accB_we=1;accB_din=accB_q+pending_addB;
  end else if(eventB)begin
   accB_rd_addr=col;accB_en=1;
   if(ym==0)begin accB_we=1;accB_din=sample_add;end
  end else if(ro_run && !bank)begin
   accB_rd_addr=ro_cnt;accB_en=1;
  end
 end

 always @(posedge pclk)begin
  if(accA_en)begin
   if(accA_we)accA[accA_rd_addr]<=accA_din;
   else accA_q<=accA[accA_rd_addr];
  end
  if(accB_en)begin
   if(accB_we)accB[accB_rd_addr]<=accB_din;
   else accB_q<=accB[accB_rd_addr];
  end
 end

 always @(posedge nclk) rd_data<=mem[rd_addr[11:0]];

 always @(posedge nclk or negedge rst_n)
  if(!rst_n)begin rel<=0;pub1<=0;pub2<=0;bad1<=0;bad2<=0;fin1<=0;fin2<=0;wg1<=0;wg2<=0;committed<=0;reclaimed<=0;rgray<=0;end
  else begin
   pub1<=pub;pub2<=pub1;bad1<=bad;bad2<=bad1;fin1<=finished;fin2<=fin1;wg1<=wgray;wg2<=wg1;
   if(release_frame)begin rel<=pub2;committed<=0;reclaimed<=0;rgray<=0;end
   else begin
    if(consume_chunk)committed<=committed+next_chunk_words;
    if(reclaimed!=committed)begin reclaimed<=reclaimed_next;rgray<=(reclaimed_next>>1)^reclaimed_next;end
   end
  end

 always @(posedge pclk or negedge rst_n)
  if(!rst_n)begin
   pub<=0;rel1<=0;rel2<=0;rg1<=0;rg2<=0;active<=0;bad<=0;finished<=0;vd<=0;dd<=0;
   x<=0;y<=0;xm<=0;ym<=0;col<=0;rowsum<=0;ro_cnt<=0;ro_didx<=0;ro_dvalid<=0;ro_run<=0;bank<=0;
   pendingA<=0;pendingB<=0;pending_addrA<=0;pending_addrB<=0;pending_addA<=0;pending_addB<=0;
   count<=0;wgray<=0;
  end else begin
   rel1<=rel;rel2<=rel1;rg1<=rgray;rg2<=rg1;vd<=vs;dd<=de;

   ro_dvalid<=ro_run;
   if(ro_run)ro_didx<=ro_cnt;
   pendingA<=eventA && ym!=0;
   pendingB<=eventB && ym!=0;
   if(eventA && ym!=0)begin pending_addrA<=col;pending_addA<=sample_add;end
   if(eventB && ym!=0)begin pending_addrB<=col;pending_addB<=sample_add;end

   if(!active && pub==rel2)begin count<=0;wgray<=0;end
   if(finished && de)bad<=1;

   // 读出：每列一个像素，直接写环形缓冲
   if(ro_run)begin
    if(ro_cnt==OW-1)begin
     ro_cnt<=0;ro_run<=0;
    end else ro_cnt<=ro_cnt+1'b1;
   end
   if(ro_dvalid)begin
    if(count-readback>=4096)bad<=1;
    else begin
     mem[count[11:0]]<=ro_word;
     count<=count_next;
     wgray<=(count_next>>1)^count_next;
    end
    if(ro_didx==OW-1 && y==H)begin finished<=1;active<=0;end
   end

   if(vs && !vd)begin
    if(active)begin
     if(count!=SIZE || y!=H)bad<=1;
     finished<=1;active<=0;
    end else if(pub==rel2 && count==0)begin
     pub<=~pub;active<=1;bad<=0;finished<=0;x<=0;y<=0;xm<=0;ym<=0;col<=0;
     rowsum<=0;ro_cnt<=0;ro_dvalid<=0;ro_run<=0;bank<=0;count<=0;wgray<=0;
     pendingA<=0;pendingB<=0;
    end
   end else if(active && de)begin
    if(x>=W || y>=H)bad<=1;
    if(x<W && y<H && !bad)begin
     if(xm==0)rowsum<=pix3;
     else if(xm!=STEP-1)rowsum<=rowsum+pix3;
    end
    x<=x+1'b1;
    if(xm==STEP-1)begin xm<=0;if(col<OW-1)col<=col+1'b1;end else xm<=xm+1'b1;
   end
   if(active && dd && !de)begin
    if(x!=W)bad<=1;
    x<=0;xm<=0;col<=0;
    y<=y+1'b1;
    if(ym==STEP-1)begin
     ym<=0;bank<=~bank;ro_cnt<=0;ro_run<=1'b1;
    end else ym<=ym+1'b1;
   end
  end
endmodule
