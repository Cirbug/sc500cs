`timescale 1ns/1ps
// One concise ASCII event per probe: PASS/FAIL/TIME seq=xxxxxxxx\r\n.
module probe_uart #(
    parameter integer CLKS_PER_BIT=1085
)(input wire clk, reset, event_valid,
  input wire [1:0] event_kind,
  input wire [31:0] event_seq,
  output wire tx);
    reg active;
    reg [9:0] bits;
    reg [3:0] bit_index;
    reg [10:0] tick;
    reg [4:0] char_index;
    reg [31:0] seq;
    reg [1:0] kind;
    function [7:0] hexchar;
        input [3:0] n;
        begin hexchar = n<10 ? 8'h30+{4'b0,n} : 8'h61+{4'b0,n}-8'd10; end
    endfunction
    function [7:0] linechar;
        input [4:0] i;
        input [1:0] k;
        input [31:0] s;
        begin
            case(i)
                0: linechar=k==0 ? "P" : (k==1 ? "F" : "T");
                1: linechar=k==2 ? "I" : "A";
                2: linechar=k==0 ? "S" : (k==1 ? "I" : "M");
                3: linechar=k==0 ? "S" : (k==1 ? "L" : "E");
                4: linechar=" "; 5: linechar="s"; 6: linechar="e";
                7: linechar="q"; 8: linechar="=";
                9: linechar=hexchar(s[31:28]); 10: linechar=hexchar(s[27:24]);
                11: linechar=hexchar(s[23:20]); 12: linechar=hexchar(s[19:16]);
                13: linechar=hexchar(s[15:12]); 14: linechar=hexchar(s[11:8]);
                15: linechar=hexchar(s[7:4]); 16: linechar=hexchar(s[3:0]);
                17: linechar=13; default: linechar=10;
            endcase
        end
    endfunction
    assign tx = active ? bits[0] : 1'b1;
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            active<=0; bits<=10'h3ff; bit_index<=0; tick<=0;
            char_index<=0; seq<=0; kind<=0;
        end else if(!active) begin
            if(event_valid) begin
                active<=1; seq<=event_seq; kind<=event_kind;
                bits<={1'b1,linechar(0,event_kind,event_seq),1'b0};
                tick<=0; bit_index<=0; char_index<=0;
            end
        end else if(tick == CLKS_PER_BIT-1) begin
            tick<=0;
            if(bit_index==9) begin
                if(char_index==18) active<=0;
                else begin
                    char_index<=char_index+1'b1; bit_index<=0;
                    bits<={1'b1,linechar(char_index+1'b1,kind,seq),1'b0};
                end
            end else begin bits<={1'b1,bits[9:1]}; bit_index<=bit_index+1'b1; end
        end else tick<=tick+1'b1;
    end
endmodule
