// CSI-2 24-bit header parity column codes, low byte = Data ID.
function automatic [7:0] test_header_ecc(input [23:0] d);
    reg [7:0] e;
    begin
        e=0;
        if(d[0]) e=e^8'h07;
        if(d[1]) e=e^8'h0b;
        if(d[2]) e=e^8'h0d;
        if(d[3]) e=e^8'h0e;
        if(d[4]) e=e^8'h13;
        if(d[5]) e=e^8'h15;
        if(d[6]) e=e^8'h16;
        if(d[7]) e=e^8'h19;
        if(d[8]) e=e^8'h1a;
        if(d[9]) e=e^8'h1c;
        if(d[10]) e=e^8'h23;
        if(d[11]) e=e^8'h25;
        if(d[12]) e=e^8'h26;
        if(d[13]) e=e^8'h29;
        if(d[14]) e=e^8'h2a;
        if(d[15]) e=e^8'h2c;
        if(d[16]) e=e^8'h31;
        if(d[17]) e=e^8'h32;
        if(d[18]) e=e^8'h34;
        if(d[19]) e=e^8'h38;
        if(d[20]) e=e^8'h1f;
        if(d[21]) e=e^8'h2f;
        if(d[22]) e=e^8'h37;
        if(d[23]) e=e^8'h3b;
        test_header_ecc=e;
    end
endfunction
