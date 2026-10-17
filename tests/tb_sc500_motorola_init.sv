`timescale 1ns/1ps
// Golden fixtures are extracted from the pinned external driver and old main.
// Check complete transaction order, rollback table, reset quiet time and rerun.
module tb_sc500_motorola_init;
    reg clk=0,rst_n=0;
    always #5 clk=~clk;
    reg [23:0] reference[0:87],legacy[0:120],expected[0:110];
    reg [8:0] table_index=0;
    wire [31:0] table_data,old_data;
    wire [8:0] table_size,old_size;
    uics500reg t(table_index,table_data,table_size);
    uics500reg #(.FULL30_REFERENCE(0)) old(table_index,old_data,old_size);
    wire done,ae_done,scl;
    tri1 sda;
    uicfgcs500 #(.CLK_DIV(15),.RESET_WAIT_CYCLES(32)) cfg(
        .I_clk(clk),.I_rst_n(rst_n),.I_ae_req(1'b0),
        .I_ae(16'd3990),.I_ag(16'd80),.I_vts(16'd2000),
        .O_cam_scl(scl),.IO_cam_sda(sda),.O_cfg_done(done),.O_ae_cfg_done(ae_done));
    // Ideal ACK model: verifies digital sequencing, not physical sensor ACK.
    assign sda=(cfg.uii2c_inst.IIC_S==3)?1'b0:1'bz;
    integer i,j,n=0,cycle=0,writes=0,reset_stop=-1,runs=0;
    always @(posedge clk) cycle=cycle+1;
    always @(negedge rst_n) begin writes=0;reset_stop=-1;end
    always @(negedge cfg.iic_busy)
        if(rst_n && !done && cfg.reg_index==0 && writes==1) reset_stop=cycle;
    always @(posedge cfg.iic_req) begin
        #1;
        if(!done) begin
            if(writes>=111) $fatal(1,"Extra init transaction");
            if(cfg.wr_data[7:0]!==8'h6c ||
               {cfg.wr_data[15:8],cfg.wr_data[23:16],cfg.wr_data[31:24]}!==expected[writes])
                $fatal(1,"Wire request order at %0d data=%h",writes,cfg.wr_data);
            if(writes==1 && (reset_stop<0 || cycle-reset_stop<32))
                $fatal(1,"No quiet interval after sensor software reset");
            writes=writes+1;
        end
    end
    task wait_complete;
        integer timeout;
        begin
            timeout=0;
            while(ae_done!==1'b1) begin
                @(negedge clk);timeout=timeout+1;
                if(timeout>150000) $fatal(1,"Initialization timeout");
            end
            if(done!==1 || writes!=111) $fatal(1,"Incomplete initialization");
            runs=runs+1;
        end
    endtask
    initial begin
        $readmemh("tests/data/sc500_motorola_init.hex",reference);
        $readmemh("tests/data/sc500_legacy_init.hex",legacy);
        for(i=0;i<88;i=i+1) begin
            if(reference[i][23:8]==16'h3e01) begin expected[n]=24'h3e0000;n=n+1;end
            if(reference[i]==24'h010001) begin
                expected[n]=24'h3e0808;expected[n+1]=24'h3e095f;n=n+2;
            end
            expected[n]=(reference[i][23:8]==16'h3e02) ? 24'h3e0260 : reference[i];n=n+1;
            if(reference[i][23:8]==16'h320d) begin
                expected[n]=24'h30183a;expected[n+1]=24'h30310a;n=n+2;
                // Retain the existing board geometry, VTS and crop offsets.
                for(j=22;j<34;j=j+1) begin expected[n]=legacy[j];n=n+1;end
                for(j=36;j<42;j=j+1) begin expected[n]=legacy[j];n=n+1;end
            end
        end
        if(n!=111) $fatal(1,"Reference adaptation length");
        #1;
        if(table_size!=111 || old_size!=121) $fatal(1,"Table count");
        for(i=0;i<512;i=i+1) begin
            table_index=i;#1;
            if(table_data !== (i<111 ? {8'd0,expected[i]} : 32'd0)) $fatal(1,"Reference LUT %0d",i);
            if(old_data !== (i<121 ? {8'd0,legacy[i]} : 32'd0)) $fatal(1,"Rollback LUT %0d",i);
        end
        @(negedge clk);rst_n=1;wait_complete;
        // Reset after running, then interrupt a subsequent configuration.
        rst_n=0;repeat(8)@(negedge clk);rst_n=1;
        wait(writes==20);@(negedge clk);rst_n=0;
        repeat(8)@(negedge clk);rst_n=1;wait_complete;
        $display("PASS SC500 Motorola: all 88 reference writes/adaptations, exact legacy121, reset gaps, interrupted restart, completed runs=%0d",runs);
        $finish;
    end
    initial begin #5000000;$fatal(1,"Watchdog");end
endmodule
