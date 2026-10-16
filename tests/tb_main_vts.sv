`timescale 1ns/1ps
module tb_main_vts;
    reg apb_clk=0,cam_clk=0,rst=1;
    always #7 apb_clk=~apb_clk;
    always #5 cam_clk=~cam_clk;
    reg [19:0] addr=0;reg sel=0,en=0,wr=0;reg [31:0] data=0;reg [3:0] strobe=15;
    wire [31:0] rd;wire [15:0] desired_ae,desired_ag,desired_vts;
    wire [22:0] disp;
    mcu_ui_apb_regs apb(.I_clk(apb_clk),.I_rst(rst),.I_button(4'hf),.I_usb_int_n(1'b1),
        .I_paddr(addr),.I_psel(sel),.I_penable(en),.I_pwrite(wr),.I_pwdata(data),.I_pstrobe(strobe),.O_prdata(rd),
        .O_exposure(desired_ae),.O_gain(desired_ag),.O_vts(desired_vts),.O_camera_display(disp));
    wire [47:0] bundle;
    camera_menu_cdc #(.WIDTH(48),.RESET_VALUE({16'd3990,16'd80,16'd2000})) cdc(apb_clk,cam_clk,!rst,{desired_ae,desired_ag,desired_vts},bundle);
    wire [15:0] ae,ag,vts;wire req,done,ae_done,scl;tri1 sda;
    ae_set ctl(.I_clk(cam_clk),.I_rst(rst),.I_btn(4'hf),.I_mcu_control_en(1'b1),
        .I_mcu_ae(bundle[47:32]),.I_mcu_ag(bundle[31:16]),.I_mcu_vts(bundle[15:0]),
        .I_cam_cfg_done(done),.I_ae_cfg_done(ae_done),.O_ae_req(req),.O_ae(ae),.O_ag(ag),.O_vts(vts));
    uicfgcs500 #(.CLK_DIV(15)) cfg(.I_clk(cam_clk),.I_rst_n(!rst),.I_ae_req(req),.I_ae(ae),.I_ag(ag),.I_vts(vts),
        .O_cam_scl(scl),.IO_cam_sda(sda),.O_cfg_done(done),.O_ae_cfg_done(ae_done));
    assign sda=(cfg.uii2c_inst.IIC_S==3)?1'b0:1'bz;
    task write_reg(input [7:0] a,input [31:0] d,input [3:0] strb=15);
        begin @(negedge apb_clk);addr=a;data=d;sel=1;wr=1;en=0;strobe=strb;
            @(negedge apb_clk);en=1;@(negedge apb_clk);sel=0;wr=0;en=0;strobe=15;end
    endtask
    task read_check(input [7:0] a,input [31:0] expected);
        begin @(negedge apb_clk);addr=a;sel=1;en=1;wr=0;#1;if(rd!==expected)$fatal(1,"read %h got %h expected %h",a,rd,expected);
            @(negedge apb_clk);sel=0;en=0;end
    endtask
    integer writes=0,groups=0,index=0,k,expected_v;
    reg [15:0] ra,rv=2000,re=3990,applied_e=3990,applied_v=2000;
    reg [7:0] byte_data;reg [47:0] held;
    function [15:0] expected_addr(input integer n);
        case(n)0,8,9:expected_addr=16'h3800;1:expected_addr=16'h320e;2:expected_addr=16'h320f;
            3:expected_addr=16'h3e00;4:expected_addr=16'h3e01;5:expected_addr=16'h3e02;
            6:expected_addr=16'h3e08;7:expected_addr=16'h3e09;endcase
    endfunction
    always @(posedge cfg.iic_req)begin
        #1;writes=writes+1;ra={cfg.wr_data[15:8],cfg.wr_data[23:16]};byte_data=cfg.wr_data[31:24];
        if(ra==0)$fatal(1,"zero register write");
        if(done)begin
            if(ra!==expected_addr(index))$fatal(1,"wrong group order");
            if(index==0)begin held={ae,ag,vts};if(byte_data!=0)$fatal(1,"group start");end
            if(held!=={ae,ag,vts})$fatal(1,"transaction tore");
            case(index)
                1:rv[15:8]=byte_data;2:rv[7:0]=byte_data;
                3:begin if(byte_data[7:4]!=0)$fatal(1,"exposure high bits");re[15:12]=byte_data[3:0];end
                4:re[11:4]=byte_data;5:re[3:0]=byte_data[7:4];
                8:if(byte_data!=16)$fatal(1,"group end");
                9:begin
                    if(byte_data!=96 || rv<1980 || rv>2500 || re<3 || re>2*rv-10)$fatal(1,"illegal sensor command");
                    if({re,rv}!={ae,vts})$fatal(1,"command encoding mismatch");
                    applied_e=re;applied_v=rv;groups=groups+1;
                end
            endcase
            index=index==9?0:index+1;
        end
    end
    task settled(input integer e,input integer v);
        integer timeout;
        begin timeout=0;
            while(!(done&&ae_done&&!req&&ae==e&&vts==v&&applied_e==e&&applied_v==v))begin
                @(negedge cam_clk);timeout=timeout+1;if(timeout>200000)$fatal(1,"config timeout");end
            repeat(30)@(negedge cam_clk);
        end
    endtask
    initial begin
        repeat(10)@(negedge apb_clk);rst=0;settled(3990,2000);
        if(writes!=131)$fatal(1,"startup writes %d",writes);
        read_check(8'ha0,32'h56545331);read_check(8'h9c,2000);
        write_reg(8'h9c,3000,1);read_check(8'h9c,2000); // reject half a VTS
        write_reg(8'ha4,23'h642500);read_check(8'ha4,23'h642500);
        write_reg(8'ha4,0,1);read_check(8'ha4,23'h642500);
        write_reg(8'h9c,4000);read_check(8'h9c,2500);write_reg(8'h10,65535);settled(4990,2500);
        write_reg(8'h9c,0);read_check(8'h10,3950);settled(3950,1980);
        write_reg(8'h9c,2500);write_reg(8'h10,65535);settled(4990,2500);
        write_reg(8'h9c,2000);read_check(8'h10,3990);settled(3990,2000);
        write_reg(8'h10,0);settled(3,2000);
        // Sweep every 16-bit VTS write and enforce the APB-side exposure invariant.
        for(k=0;k<65536;k=k+1)begin
            write_reg(8'h9c,k);expected_v=k<1980?1980:k>2500?2500:k;
            if(desired_vts!=expected_v || desired_ae<3 || desired_ae>2*desired_vts-10)$fatal(1,"APB VTS clamp %d",k);
        end
        // Bursts change both fields while an earlier I2C group remains in flight.
        for(k=0;k<200;k=k+1)begin write_reg(8'h9c,1980+(k*137)%521);write_reg(8'h10,6000+k*11);end
        write_reg(8'h9c,2400);write_reg(8'h10,5100);settled(4790,2400);
        write_reg(8'h0c,7);read_check(8'h0c,7);
        $display("PASS MAIN VTS 1980..2500: all 65536 VTS values, APB limits/readback/strobes, group hold, busy coalescing; groups=%0d writes=%0d",groups,writes);$finish;
    end
    initial begin #60000000;$fatal(1,"timeout");end
endmodule
