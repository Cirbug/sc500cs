`timescale 1ns/1ps
module tb_red_track_mailbox;
    reg pclk=0,aclk=0,rst=0,run_apb=1;
    always #7 pclk=~pclk;
    always #11 if(run_apb) aclk=~aclk;
    reg enable=0,reacquire=0,result=0,valid=0;
    reg [1:0] state=0,dx=0,dy=0,lx=0,ly=0;
    reg signed [12:0] ex=0,ey=0;
    wire [31:0] status,errors;
    red_track_mailbox dut(pclk,aclk,rst,enable,reacquire,result,valid,state,dx,dy,lx,ly,ex,ey,status,errors);
    reg [19:0] addr=0; reg sel=0,en=0,wr=0;reg [31:0] wd=0;wire [31:0] rd;
    wire [15:0] pan,tilt;wire [2:0] mode;
    mcu_ui_apb_regs apb(.I_clk(aclk),.I_rst(!rst),.I_button(4'hf),.I_usb_int_n(1'b1),
        .I_paddr(addr),.I_psel(sel),.I_penable(en),.I_pwrite(wr),.I_pwdata(wd),.I_pstrobe(4'hf),
        .I_track_status(status),.I_track_errors(errors),.O_prdata(rd),
        .O_servo_pan_us(pan),.O_servo_tilt_us(tilt),.O_image_step(mode));
    task settle; repeat(30) @(negedge pclk); endtask
    task read_check(input [7:0] a,input [31:0] expected);
        @(negedge aclk);addr=a;sel=1;en=1;wr=0;#1;
        if(rd!==expected)$fatal(1,"APB %h got %h expected %h",a,rd,expected);
        @(negedge aclk);sel=0;en=0;
    endtask
    task write_reg(input [7:0] a,input [31:0] data);
        @(negedge aclk);addr=a;wd=data;sel=1;en=0;wr=1;
        @(negedge aclk);en=1;@(negedge aclk);sel=0;en=0;wr=0;
    endtask
    reg [31:0] old_status,old_errors;
    reg [57:0] previous_held; reg busy_before=0;
    always @(negedge pclk) begin
        if(rst && busy_before && dut.held!==previous_held)$fatal(1,"bundle changed before ack");
        previous_held=dut.held;busy_before=rst && (dut.req!=dut.ack_sync[2]);
    end
    initial begin
        #2;rst=0;#30;rst=1;settle();
        read_check(8'ha8,32'h54524b31);
        if(status[15:0]!==0)$fatal(1,"reset must be invalid");
        @(negedge pclk);enable=1;settle();
        @(negedge pclk);valid=1;state=1;dx=2;dy=1;lx=3;ly=2;ex=400;ey=-120;result=1;
        @(negedge pclk);result=0;settle();
        if(status[15:0]!==16'hd9e0 || errors!=={3'd0,13'h1f88,3'd0,13'd400})$fatal(1,"packet packing");
        read_check(8'hac,status);read_check(8'hb0,errors);
        old_status=status;old_errors=errors;
        @(negedge aclk);run_apb=0;
        @(negedge pclk);ex=-700;ey=250;dx=1;result=1;
        @(negedge pclk);result=0;
        repeat(8)@(negedge pclk);
        reacquire=1;@(negedge pclk);reacquire=0;
        repeat(8)@(negedge pclk);
        if(status!==old_status || errors!==old_errors)$fatal(1,"stopped destination changed");
        run_apb=1;settle();settle();
        if(status[14] || status[11:0] || errors)$fatal(1,"busy reacquire must eventually invalidate");
        @(negedge pclk);enable=0;settle();
        if(status[15:0] || errors)$fatal(1,"mode exit must invalidate");
        write_reg(8'h50,2600);write_reg(8'h54,100);write_reg(8'h58,5);
        read_check(8'h50,2500);read_check(8'h54,500);read_check(8'h58,5);
        $display("PASS red mailbox: asynchronous clocks, held bundle, APB ABI, busy reacquire, mode exit, PWM registers");$finish;
    end
    initial begin #100000;$fatal(1,"timeout");end
endmodule
