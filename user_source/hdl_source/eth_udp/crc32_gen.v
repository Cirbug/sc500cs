`timescale 1ns / 1ps

module crc32_gen(
input   reset,
input   clk,
input   CRC32_en,         //CRC校验使能信号
input   CRC32_init,       //CRC校验值初始化信号
input   CRC_read, 
	 //input   CRC32_valid,      //CRC校验值维持有效
input  [7:0]  data,	 
output [7:0]  CRC_out 
);

reg [31:0]   CRC_temp;

assign CRC_out = CRC_read ? ~{CRC_temp[24], CRC_temp[25], CRC_temp[26], CRC_temp[27],
	                           CRC_temp[28], CRC_temp[29], CRC_temp[30], CRC_temp[31]} : 8'h00;			  
    

always@(posedge clk or posedge reset)         
   if(reset)
	    CRC_temp <= 32'hffffffff;		  
   else if(CRC32_init)
	    CRC_temp <= 32'hffffffff;
   else if(CRC32_en)
	  begin
		 CRC_temp[0]<=CRC_temp[24]^CRC_temp[30]^data[1]^data[7];
		 CRC_temp[1]<=CRC_temp[25]^CRC_temp[31]^data[0]^data[6]^CRC_temp[24]^CRC_temp[30]^data[1]^data[7];
		 CRC_temp[2]<=CRC_temp[26]^data[5]^CRC_temp[25]^CRC_temp[31]^data[0]^data[6]^CRC_temp[24]^CRC_temp[30]^data[1]^data[7];
		 CRC_temp[3]<=CRC_temp[27]^data[4]^CRC_temp[26]^data[5]^CRC_temp[25]^CRC_temp[31]^data[0]^data[6];
		 CRC_temp[4]<=CRC_temp[28]^data[3]^CRC_temp[27]^data[4]^CRC_temp[26]^data[5]^CRC_temp[24]^CRC_temp[30]^data[1]^data[7];
		 CRC_temp[5]<=CRC_temp[29]^data[2]^CRC_temp[28]^data[3]^CRC_temp[27]^data[4]^CRC_temp[25]^CRC_temp[31]^data[0]^data[6]^CRC_temp[24]^CRC_temp[30]^data[1]^data[7];
		 CRC_temp[6]<=CRC_temp[30]^data[1]^CRC_temp[29]^data[2]^CRC_temp[28]^data[3]^CRC_temp[26]^data[5]^CRC_temp[25]^CRC_temp[31]^data[0]^data[6];
		 CRC_temp[7]<=CRC_temp[31]^data[0]^CRC_temp[29]^data[2]^CRC_temp[27]^data[4]^CRC_temp[26]^data[5]^CRC_temp[24]^data[7];
		 CRC_temp[8]<=CRC_temp[0]^CRC_temp[28]^data[3]^CRC_temp[27]^data[4]^CRC_temp[25]^data[6]^CRC_temp[24]^data[7];
		 CRC_temp[9]<=CRC_temp[1]^CRC_temp[29]^data[2]^CRC_temp[28]^data[3]^CRC_temp[26]^data[5]^CRC_temp[25]^data[6];
		 CRC_temp[10]<=CRC_temp[2]^CRC_temp[29]^data[2]^CRC_temp[27]^data[4]^CRC_temp[26]^data[5]^CRC_temp[24]^data[7];
		 CRC_temp[11]<=CRC_temp[3]^CRC_temp[28]^data[3]^CRC_temp[27]^data[4]^CRC_temp[25]^data[6]^CRC_temp[24]^data[7];
		 CRC_temp[12]<=CRC_temp[4]^CRC_temp[29]^data[2]^CRC_temp[28]^data[3]^CRC_temp[26]^data[5]^CRC_temp[25]^data[6]^CRC_temp[24]^CRC_temp[30]^data[1]^data[7];
		 CRC_temp[13]<=CRC_temp[5]^CRC_temp[30]^data[1]^CRC_temp[29]^data[2]^CRC_temp[27]^data[4]^CRC_temp[26]^data[5]^CRC_temp[25]^CRC_temp[31]^data[0]^data[6];
		 CRC_temp[14]<=CRC_temp[6]^CRC_temp[31]^data[0]^CRC_temp[30]^data[1]^CRC_temp[28]^data[3]^CRC_temp[27]^data[4]^CRC_temp[26]^data[5];
		 CRC_temp[15]<=CRC_temp[7]^CRC_temp[31]^data[0]^CRC_temp[29]^data[2]^CRC_temp[28]^data[3]^CRC_temp[27]^data[4];
		 CRC_temp[16]<=CRC_temp[8]^CRC_temp[29]^data[2]^CRC_temp[28]^data[3]^CRC_temp[24]^data[7];
		 CRC_temp[17]<=CRC_temp[9]^CRC_temp[30]^data[1]^CRC_temp[29]^data[2]^CRC_temp[25]^data[6];
		 CRC_temp[18]<=CRC_temp[10]^CRC_temp[31]^data[0]^CRC_temp[30]^data[1]^CRC_temp[26]^data[5];
		 CRC_temp[19]<=CRC_temp[11]^CRC_temp[31]^data[0]^CRC_temp[27]^data[4];
		 CRC_temp[20]<=CRC_temp[12]^CRC_temp[28]^data[3];
		 CRC_temp[21]<=CRC_temp[13]^CRC_temp[29]^data[2];
		 CRC_temp[22]<=CRC_temp[14]^CRC_temp[24]^data[7];
		 CRC_temp[23]<=CRC_temp[15]^CRC_temp[25]^data[6]^CRC_temp[24]^CRC_temp[30]^data[1]^data[7];
		 CRC_temp[24]<=CRC_temp[16]^CRC_temp[26]^data[5]^CRC_temp[25]^CRC_temp[31]^data[0]^data[6];
		 CRC_temp[25]<=CRC_temp[17]^CRC_temp[27]^data[4]^CRC_temp[26]^data[5];
		 CRC_temp[26]<=CRC_temp[18]^CRC_temp[28]^data[3]^CRC_temp[27]^data[4]^CRC_temp[24]^CRC_temp[30]^data[1]^data[7];
		 CRC_temp[27]<=CRC_temp[19]^CRC_temp[29]^data[2]^CRC_temp[28]^data[3]^CRC_temp[25]^CRC_temp[31]^data[0]^data[6];
		 CRC_temp[28]<=CRC_temp[20]^CRC_temp[30]^data[1]^CRC_temp[29]^data[2]^CRC_temp[26]^data[5];
		 CRC_temp[29]<=CRC_temp[21]^CRC_temp[31]^data[0]^CRC_temp[30]^data[1]^CRC_temp[27]^data[4];
		 CRC_temp[30]<=CRC_temp[22]^CRC_temp[31]^data[0]^CRC_temp[28]^data[3];
		 CRC_temp[31]<=CRC_temp[23]^CRC_temp[29]^data[2];
	  end
	else if(CRC_read)
	    CRC_temp <= {CRC_temp[23:0], 8'hff};
		 
endmodule
