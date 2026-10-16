// Group 0 commits VTS, exposure and gain as one settings transaction.
module uics500regAE(input [8:0] REG_INDEX,output reg [31:0] REG_DATA,
    output [8:0] REG_SIZE,input [15:0] I_AE,I_AG,I_VTS);
    assign REG_SIZE=9'd10;
    always @* case(REG_INDEX)
        0:REG_DATA={16'h3800,8'h00};
        1:REG_DATA={16'h320e,I_VTS[15:8]};
        2:REG_DATA={16'h320f,I_VTS[7:0]};
        3:REG_DATA={16'h3e00,4'h0,I_AE[15:12]};
        4:REG_DATA={16'h3e01,I_AE[11:4]};
        5:REG_DATA={16'h3e02,I_AE[3:0],4'h0};
        6:REG_DATA={16'h3e08,I_AG[15:8]};
        7:REG_DATA={16'h3e09,I_AG[7:0]};
        8:REG_DATA={16'h3800,8'h10};
        9:REG_DATA={16'h3800,8'h60};
        default:REG_DATA=0;
    endcase
endmodule
