`timescale 1ns / 1ps

module tb_top();

parameter period=10;
reg hclk=1'b1;
reg hresetn=1'b1;


always #(period/2)
hclk=~hclk;
initial
begin
   hresetn = 1'b0;
   #(100*period)
   hresetn = 1'b1;
end

reg          hbusreq  ;
wire         hgrant   ;
reg  [31:0]  haddr    ;
reg  [ 1:0]  htrans   ;
reg          hwrite   ;
reg  [ 2:0]  hsize    ;
reg  [ 2:0]  hburst   ;
reg  [31:0]  hwdata   ;
wire [31:0]  hrdata   ;
wire [ 1:0]  hresp    ;
wire         hready   ;
wire         hsel     ;

reg [31:0] data_burst_wr[32767:0];
reg [31:0] data_burst_SIMD_wr[32767:0];
reg [31:0] data_burst_rd[2047:0];
reg [31:0] rdata;
integer    sadr, i, j;
integer    error,w_r_val,w_r_chanel;

parameter saddr=32'h0000_0000;
parameter RAM_CTRL_ADDR = 14'h2000;
parameter RAM_SEL_ADDR  = 14'h2004;
parameter APU_READY_ADDR      = 14'h2008;
parameter CPL_ADDR      = 14'h200c;
integer IN_C = 64;
integer OUT_C = 64;
integer IN_H = 8;
integer IN_W = 8;
integer STRIDE1 = 1;
integer STRIDE2 = 0;
integer inst = 0;
integer kernal_size = 3;
integer IN_H_LOG = 3;
integer IN_C_LOG = 6;
integer OUT_C_LOG = 6;
reg [31:0] instruction;



wire int_cal;

integer fp_datao_w;
//write data


initial begin
    hbusreq= 0;
    haddr  = 0;
    htrans = 0;
    hwrite = 0;
    hsize  = 0;
    hburst = 0;
    hwdata = 0;
    wait  (hresetn==1'b0);
    wait  (hresetn==1'b1);
    repeat (20) @ (posedge hclk);

    // $PATH = C:/D/buaa/25_Neuro_network_accelerator/APU
	//set ram ctrl
    ahb_write(RAM_CTRL_ADDR, 4, 32'h3 );
    //---------------------------Set Input----------------------------//      
    
    //set in data
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/input_binary.txt",data_burst_wr);

    //write in ram  
    ahb_write(RAM_SEL_ADDR, 4, 128);
    ahb_write_burst(0, 0, 32*32*64/32);

    //---------------------------Run layer1--------------------------//
 
    //set layer1.0      conv and SIMD parameter
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer1.0.conv1.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer1.0.bn1_combined.txt",data_burst_SIMD_wr);
    //set layer1.0 instruction {opcode, kernalSize, logInHW, logInC, logOutC, stride1, stride2, wAdddr, bnAddr}
    conv_layer(2'b00, 2'd3, 3'd5, 4'd6, 4'd6, 2'd1, 2'd0, 8'd0, 5'd0 ,0);

	//set layer1.0      conv and SIMD parameter
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer1.0.conv2.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer1.0.bn3_combined.txt",data_burst_SIMD_wr);
    //set layer1.0 instruction {opcode, kernalSize, logInHW, logInC, logOutC, stride1, stride2, wAdddr, bnAddr}
    conv_layer(2'b00, 2'd3, 3'd5, 4'd6, 4'd6, 2'd1, 2'd0, 8'd9, 5'd1 ,1);

	//set layer1.1      conv and SIMD parameter
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer1.1.conv1.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer1.1.bn1_combined.txt",data_burst_SIMD_wr);
    //set layer1.1 instruction {opcode, kernalSize, logInHW, logInC, logOutC, stride1, stride2, wAdddr, bnAddr}
    conv_layer(2'b00, 2'd3, 3'd5, 4'd6, 4'd6, 2'd1, 2'd0, 8'd18, 5'd2 ,2);

	//set layer1.1      conv and SIMD parameter
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer1.1.conv2.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer1.1.bn3_combined.txt",data_burst_SIMD_wr);
    //set layer1.1 instruction {opcode, kernalSize, logInHW, logInC, logOutC, stride1, stride2, wAdddr, bnAddr}
    conv_layer(2'b00, 2'd3, 3'd5, 4'd6, 4'd6, 2'd1, 2'd0, 8'd27, 5'd3 ,3);

	//---------------------------Run layer2--------------------------//
 
    //set layer2.0      conv and SIMD parameter C: 64->128
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer2.0.conv1.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer2.0.bn1_combined.txt",data_burst_SIMD_wr);
    //set layer2.0 instruction {opcode, kernalSize, logInHW, logInC, logOutC, stride1, stride2, wAdddr, bnAddr}
    conv_layer(2'b00, 2'd3, 3'd5, 4'd6, 4'd7, 2'd2, 2'd0, 8'd36, 5'd4 ,4); //wAdddr += cyclePerTime * timePerRound

	//set layer2.0      conv and SIMD parameter resident
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer2.0.conv2_combined.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer2.0.bn3_combined.txt",data_burst_SIMD_wr);
    //set layer2.0 instruction {opcode, kernalSize, logInHW, logInC, logOutC, stride1, stride2, wAdddr, bnAddr}+36
    conv_resident_layer(2'b01, 2'd3, 3'd4, 4'd7, 4'd7, 2'd1, 2'd2, 8'd54, 5'd6 ,5);

	
	//set layer2.1      conv and SIMD parameter
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer2.1.conv1.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer2.1.bn1_combined.txt",data_burst_SIMD_wr);
    //set layer2.1 instruction {opcode, kernalSize, logInHW, logInC, logOutC, stride1, stride2, wAdddr, bnAddr}
    conv_layer(2'b00, 2'd3, 3'd4, 4'd7, 4'd7, 2'd1, 2'd0, 8'd92, 5'd10 ,6);

	//set layer2.1      conv and SIMD parameter
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer2.1.conv2.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer2.1.bn3_combined.txt",data_burst_SIMD_wr);
    //set layer2.1 instruction {opcode, kernalSize, logInHW, logInC, logOutC, stride1, stride2, wAdddr, bnAddr}
    conv_layer(2'b00, 2'd3, 3'd4, 4'd7, 4'd7, 2'd1, 2'd0, 8'd128, 5'd14 ,7);

	//set ram ctrl
    ahb_write(RAM_CTRL_ADDR, 4, 32'h0 ); //apu读写 //这是完整的开始计算到计算完成读取的过程吗，有待商榷

    //write apu ready
    ahb_write(APU_READY_ADDR, 4, 1 ); //apu计算

    //wait interrupt
    while (int_cal==1'b0) @ (posedge hclk);
    
    //clear interrupt
    ahb_read (CPL_ADDR, 4, rdata);
    $display($time,, " cpl_data: %d ", rdata);
    ahb_write(APU_READY_ADDR, 4, 0 );
    //read data
    //ahb_write(RAM_CTRL_ADDR, 4, 32'h3 );//ahb读写
    //ahb_write(RAM_SEL_ADDR, 4, 128);//129 for 1,3    128 for 2,4
    //ahb_read_burst_save(0,4*512);//write 2048 here means write 2048 rows

//请补充此处的tb    
    //---------------------------Run layer3--------------------------//

    /*
    input [1:0] opcode;
	input [1:0] kernalSize;
	input [2:0] logInHW;
    input [3:0] logInC;
    input [3:0] logOutC;
	input [1:0] stride1;
	input [1:0] stride2;
	input [7:0] wAddr;
	input [4:0] bnAddr;
    input [3:0] worksheet_waddr;
    */
    
    ahb_write(RAM_CTRL_ADDR, 4, 32'h3 ); //ahb读写

    $readmemb("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer3.0.conv1.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer3.0.bn1_combined.txt",data_burst_SIMD_wr);
    conv_layer(2'b00, 2'd3, 3'd4, 4'd7, 4'd8, 2'd2, 2'd0, 8'd0, 5'd0, 0); //conv4 waddr=128+36

    $readmemb("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer3.0.conv2_combined.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer3.0.bn3_combined.txt",data_burst_SIMD_wr);
    conv_resident_layer(2'b01, 2'd3, 3'd3, 4'd8, 4'd8, 2'd1, 2'd2, 8'd72, 5'd4, 1); //conv5 + conv7 waddr=164+4*18

    //set ram ctrl
    ahb_write(RAM_CTRL_ADDR, 4, 32'h0 ); //apu读写

    //write apu ready
    ahb_write(APU_READY_ADDR, 4, 1 ); //apu计算

    //wait interrupt
    while (int_cal==1'b0) @ (posedge hclk);
    
    //clear interrupt
    ahb_read (CPL_ADDR, 4, rdata);
    $display($time,, " cpl_data: %d ", rdata);
    ahb_write(APU_READY_ADDR, 4, 0 );
/*
    //read data
    ahb_write(RAM_CTRL_ADDR, 4, 32'h3 );//ahb读写
    ahb_write(RAM_SEL_ADDR, 4, 128);//129 for 1,3    128 for 2,4
    ahb_read_burst_save(0,4*512);//write 2048 here means write 2048 rows
*/

    ahb_write(RAM_CTRL_ADDR, 4, 32'h3 ); //ahb读写
    
    $readmemb("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer3.1.conv1.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer3.1.bn1_combined.txt",data_burst_SIMD_wr);
    conv_layer(2'b00, 2'd3, 3'd3, 4'd8, 4'd8, 2'd1, 2'd0, 8'd0, 5'd0, 0); //conv5 waddr=236+38*4

    //set ram ctrl
    ahb_write(RAM_CTRL_ADDR, 4, 32'h0 ); //apu读写

    //write apu ready
    ahb_write(APU_READY_ADDR, 4, 1 ); //apu计算

    //wait interrupt
    while (int_cal==1'b0) @ (posedge hclk);
    
    //clear interrupt
    ahb_read (CPL_ADDR, 4, rdata);
    $display($time,, " cpl_data: %d ", rdata);
    ahb_write(APU_READY_ADDR, 4, 0 );


    ahb_write(RAM_CTRL_ADDR, 4, 32'h3 ); //ahb读写

    $readmemb("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer3.1.conv2.txt",data_burst_wr);
    $readmemb ("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/layer3.1.bn3_combined.txt",data_burst_SIMD_wr);
    conv_layer(2'b00, 2'd3, 3'd3, 4'd8, 4'd8, 2'd1, 2'd0, 8'd0, 5'd0, 0); //conv5 waddr=388+36*4
	
    //set ram ctrl
    ahb_write(RAM_CTRL_ADDR, 4, 32'h0 ); //apu读写

    //write apu ready
    ahb_write(APU_READY_ADDR, 4, 1 ); //apu计算

    //wait interrupt
    while (int_cal==1'b0) @ (posedge hclk);
    
    //clear interrupt
    ahb_read (CPL_ADDR, 4, rdata);
    $display($time,, " cpl_data: %d ", rdata);
    ahb_write(APU_READY_ADDR, 4, 0 );
    
    //read data
    ahb_write(RAM_CTRL_ADDR, 4, 32'h3 );
    ahb_write(RAM_SEL_ADDR, 4, 128);//129 for 1,3    128 for 2,4
    ahb_read_burst_save(0,4*512);//write 2048 here means write 2048 rows
    repeat (80000) @ (posedge hclk);


 
    //---------------------------
    repeat (20) @ (posedge hclk);
    $finish(2);
end


wire                         data_ram_ctrl     ;
wire                         conv_ram_ctrl     ;
wire       [31:0]            ir                ;
wire       [1:0]             cal_cpl           ;

assign hgrant = hbusreq;// no arbiter
assign hsel   = htrans[1]; // no address decoder
assign cal_cpl = 2'b10;

Top dut_apu_inst(
.nRst           ( hresetn       ),
.clk              ( hclk          ),
.hsel              ( htrans[1]     ),
.haddr             ( haddr             ),
.htrans            ( htrans        ),
.hwrite            ( hwrite        ),
.hsize             ( hsize         ),
.hburst            ( hburst        ),
.hwdata            ( hwdata        ),
.hrdata            ( hrdata        ),
.hresp             ( hresp         ),
.hready            (               ),
.hreadyout         ( hready        ),
.int_cal           ( int_cal       ),
.hlock             ( 1'b0),   // Not used in this module
.hprot             (4'b0)   // Not used in this module
 );
 
/*
initial begin
 $fsdbDumpfile("top.fsdb");
 $fsdbDumpvars(0,"+mda");
end
*/ //undefined systemtask

//////////////////////////////////////////////////////////////////////////////////
// task define
//////////////////////////////////////////////////////////////////////////////////
task conv_layer;
	input [1:0] opcode;
	input [1:0] kernalSize;
	input [2:0] logInHW;
    input [3:0] logInC;
    input [3:0] logOutC;
	input [1:0] stride1;
	input [1:0] stride2;
	input [7:0] wAddr;
	input [4:0] bnAddr;
    input [3:0] worksheet_waddr;
    integer i;
    integer j;
    begin
		
        //kernalSize*kernalSize*($pow(2,logInC))/64; //cyclepertime
        //($pow(2,logOutC))/64 //timeperround
        //WeightSRAM reg [P_BITWIDTH-1: 0] rData [P_WORDS-1: 0];   parameter  P_WORDS = 256, parameter P_BITWIDTH = 64
        //一个weightsram(conv ram)存储64x256，存64x8x32

        //target_ahb_ram_addr = (w_addr_arg*8) + (lwc*j*4)
        //lwc = wpcke * kernel_size_val * kernel_size_val * nicpg 
        //wpcke = 2; nicpg = (1<<log_in_c)//64
        //ahb协议32b,wpcke辅助写64b数据

        //target_ahb_ram_addr=wAddr*8+2*kernalSize*kernalSize*($pow(2,logInC))/64
        /*
        task ahb_write_burst;
            input  [31:0] start_addr;
            input  [31:0] addr;
            input  [31:0] leng;
        */

 	//write conv weight ram  
	//请自行编写
        begin
            for(j=0; j<(1<<logOutC)/64; j=j+1)
            begin
                for(i=0; i<64; i=i+1)
                begin
                    ahb_write(RAM_SEL_ADDR, 4, i+64);//片选信号选择conv_ram
                    ahb_write_burst((i+j*64)*(2*kernalSize*kernalSize*((1<<logInC)/64)), wAddr*8+2*kernalSize*kernalSize*((1<<logInC)/64)*j*4, kernalSize == 'd3 ? 18*((1<<logInC)/64) : 2*((1<<logInC)/64));
                end
            end
        end
 	//write SIMD ram
	//请自行编写
        begin
            for(j=0; j<(1<<logOutC)/64; j=j+1)
            begin
                for(i=0; i<64; i=i+1)
                begin
                    ahb_write(RAM_SEL_ADDR, 4, i); //片选信号选择bn_ram
                    ahb_write_SIMD_burst((i+j*64), (bnAddr*4)+(j*4), 1);
                end
            end
        end

	//write work sheet
   	//请自行编写
        begin
            ahb_write(RAM_SEL_ADDR, 4, 130); //……选择workseet
            ahb_write(worksheet_waddr*4, 4, {opcode, kernalSize, logInHW, logInC, logOutC, stride1, stride2, wAddr, bnAddr});
        end
    end
endtask

task conv_resident_layer;
	input [1:0] opcode;
	input [1:0] kernalSize;
	input [2:0] logInHW;
    input [3:0] logInC;
    input [3:0] logOutC;
	input [1:0] stride1;
	input [1:0] stride2;
	input [7:0] wAddr;
	input [4:0] bnAddr;
    input [3:0] worksheet_waddr;
    integer i;
    integer j;
    begin

 	//write conv weight ram  
	//请自行编写
        begin
            for(j=0; j<(1<<logOutC)/64; j=j+1)
            begin
                for(i=0; i<64; i=i+1)
                begin
                    ahb_write(RAM_SEL_ADDR, 4, i+64);//片选信号选择conv_ram
                    ahb_write_burst((i+j*64)*((2*kernalSize*kernalSize+1)*((1<<logInC)/64)), wAddr*8+(2*kernalSize*kernalSize+1)*((1<<logInC)/64)*j*4, logInHW == 'd4 ? 38 : 76);//logInHW == 'd4为conv3+conv6
                end
            end
        end
 	//write SIMD ram
	//请自行编写
        begin
            for(j=0; j<(1<<logOutC)/64; j=j+1)
            begin
                for(i=0; i<64; i=i+1)
                begin
                    ahb_write(RAM_SEL_ADDR, 4, i); //片选信号选择bn_ram
                    ahb_write_SIMD_burst((i+j*64), (bnAddr*4)+(j*4), 1);
                end
            end
        end

	//write work sheet
   	//请自行编写
        begin
            ahb_write(RAM_SEL_ADDR, 4, 130); //……选择workseet
            ahb_write(worksheet_waddr*4, 4, {opcode, kernalSize, logInHW, logInC, logOutC, stride1, stride2, wAddr, bnAddr});
        end
    end
endtask

task ahb_read;
input  [31:0] address;
input  [ 2:0] size;
output [31:0] data;
begin
    @ (posedge hclk);
    hbusreq <=  1'b1;
    @ (posedge hclk);
    while ((hgrant!==1'b1)||(hready!==1'b1)) @ (posedge hclk);
    hbusreq <=  1'b0;
    haddr   <=  address;
//    hprot   <=  4'b0001; //`hprot_data
    htrans  <=  2'b10;  //`htrans_nonseq;
    hburst  <=  3'b000; //`hburst_single;
    hwrite  <=  1'b0;   //`hwrite_read;
    case (size)
    1:  hsize <=  3'b000; //`hsize_byte;
    2:  hsize <=  3'b001; //`hsize_hword;
    4:  hsize <=  3'b010; //`hsize_word;
    default: $display($time,, "error: unsupported transfer size: %d-byte", size);
    endcase
    @ (posedge hclk);
    while (hready!==1'b1) @ (posedge hclk);
    `ifndef low_power
    haddr  <=  32'b0;
//    hprot  <=  4'b0000; //`hprot_opcode
    hburst <=  3'b0;
    hwrite <=  1'b0;
    hsize  <=  3'b0;
    `endif
    htrans <=  2'b0;
    @ (posedge hclk);
    while (hready===0) @ (posedge hclk);
    data = hrdata; // must be blocking
    if (hresp!=2'b00) //if (hresp!=`hresp_okay)
        $display($time,, "error: non ok response for read");
    @ (posedge hclk);
end
endtask

//-----------------------------------------------------
task ahb_write;
input  [31:0] address;
input  [ 2:0] size;
input  [31:0] data;
begin
    @ (posedge hclk);
    hbusreq <=  1;
    @ (posedge hclk);
    while ((hgrant!==1'b1)||(hready!==1'b1)) @ (posedge hclk);
    hbusreq <=  1'b0;
    haddr   <=  address;
//    hprot   <=  4'b0001; //`hprot_data
    htrans  <=  2'b10;  //`htrans_nonseq;
    hburst  <=  3'b000; //`hburst_single;
    hwrite  <=  1'b1;   //`hwrite_write;
    case (size)
    1:  hsize <=  3'b000; //`hsize_byte;
    2:  hsize <=  3'b001; //`hsize_hword;
    4:  hsize <=  3'b010; //`hsize_word;
    default: $display($time,, "error: unsupported transfer size: %d-byte", size);
    endcase
    @ (posedge hclk);
    while (hready!==1) @ (posedge hclk);
    `ifndef low_power
    haddr  <=  32'b0;
//    hprot  <=  4'b0000; //`hprot_opcode
    hburst <=  3'b0;
    hwrite <=  1'b0;
    hsize  <=  3'b0;
    `endif
    hwdata <=  data;
    htrans <=  2'b0;
    @ (posedge hclk);
    while (hready===0) @ (posedge hclk);
    if (hresp!=2'b00) //if (hresp!=`hresp_okay)
         $display($time,, "error: non ok response write");
    `ifndef low_power
    hwdata <=  0;
    `endif
    @ (posedge hclk);
end
endtask

//-------------------------------------------------------------
task ahb_read_burst;
     input  [31:0] addr;
     input  [31:0] leng;
     integer       i;
     begin
         @ (posedge hclk);
         hbusreq <=  1'b1;
         @ (posedge hclk);
         while ((hgrant!==1'b1)||(hready!==1'b1)) @ (posedge hclk);
         haddr  <=  addr;
         htrans <=  2'b10; //`htrans_nonseq;
         if (leng==4)       hburst <=  3'b011; //`hburst_incr4;
         else if (leng==8)  hburst <=  3'b101; //`hburst_incr8;
         else if (leng==16) hburst <=  3'b111; //`hburst_incr16;
         else               hburst <=  3'b001; //`hburst_incr;
         hwrite <=  1'b0; //`hwrite_read;
         hsize  <=  3'b010; //`hsize_word;
         @ (posedge hclk);
         while (hready==1'b0) @ (posedge hclk);
         for (i=0; i<leng-1; i=i+1) begin
             haddr  <=  addr+(i+1)*4;
             htrans <=  2'b11; //`htrans_seq;
             @ (posedge hclk);
             while (hready==1'b0) @ (posedge hclk);
             data_burst_rd[i] = hrdata; // must be blocking
         end
         //hsel   <=  0;
         haddr  <=  0;
         htrans <=  0;
         hburst <=  0;
         hwrite <=  0;
         hsize  <=  0;
         hbusreq <=  1'b0;
         @ (posedge hclk);
         while (hready==0) @ (posedge hclk);
         data_burst_rd[i] = hrdata; // must be blocking
         if (hresp!=2'b00) begin //`hresp_okay
$display($time,, "error: non ok response for read");
            end
`ifdef debug
$display($time,, "info: read(%x, %d, %x)", address, size, data);
`endif
         @ (posedge hclk);
     end
endtask

task ahb_read_burst_save;     
     input  [31:0] addr;
     input  [31:0] leng;
     integer       i;
     begin
         fp_datao_w = $fopen("C:/D/buaa/25_Neuro_network_accelerator/APU/param_files/data_out.txt","w");
         @ (posedge hclk);
         hbusreq <=  1'b1;
         @ (posedge hclk);
         while ((hgrant!==1'b1)||(hready!==1'b1)) @ (posedge hclk);
         haddr  <=  addr;
         htrans <=  2'b10; //`htrans_nonseq;
         if (leng==4)       hburst <=  3'b011; //`hburst_incr4;
         else if (leng==8)  hburst <=  3'b101; //`hburst_incr8;
         else if (leng==16) hburst <=  3'b111; //`hburst_incr16;
         else               hburst <=  3'b001; //`hburst_incr;
         hwrite <=  1'b0; //`hwrite_read;
         hsize  <=  3'b010; //`hsize_word;
         @ (posedge hclk);
         while (hready==1'b0) @ (posedge hclk);
         for (i=0; i<leng-1; i=i+1) begin
             haddr  <=  addr+(i+1)*4;
             htrans <=  2'b11; //`htrans_seq;
             @ (posedge hclk);
             while (hready==1'b0) @ (posedge hclk);
             $fwrite(fp_datao_w,"%32b\n",hrdata);
             //data_burst_rd[i] = hrdata; // must be blocking
         end
         //hsel   <=  0;
         haddr  <=  0;
         htrans <=  0;
         hburst <=  0;
         hwrite <=  0;
         hsize  <=  0;
         hbusreq <=  1'b0;
         @ (posedge hclk);
         while (hready==0) @ (posedge hclk);
         $fwrite(fp_datao_w,"%32b\n",hrdata);

         //data_burst_rd[i] = hrdata; // must be blocking
         if (hresp!=2'b00) begin //`hresp_okay
$display($time,, "error: non ok response for read");
            end
`ifdef debug
$display($time,, "info: read(%x, %d, %x)", address, size, data);
`endif
         @ (posedge hclk);
         $fclose(fp_datao_w);
     end
endtask


//-------------------------------------------------------------
task ahb_write_burst;
     input  [31:0] start_addr;
     input  [31:0] addr;
     input  [31:0] leng;
     integer       i;
     begin
         @ (posedge hclk);
         hbusreq <=  1'b1;
         @ (posedge hclk);
         while ((hgrant!==1'b1)||(hready!==1'b1)) @ (posedge hclk);
         haddr  <=  addr;
         htrans <=  2'b10; //`htrans_nonseq;
         if (leng==4)       hburst <=  3'b011; //`hburst_incr4;
         else if (leng==8)  hburst <=  3'b101; //`hburst_incr8;
         else if (leng==16) hburst <=  3'b111; //`hburst_incr16;
         else               hburst <=  3'b001; //`hburst_incr;
         hwrite <=  1'b1; //`hwrite_write;
         hsize  <=  3'b010; //`hsize_word;
         for (i=0; i<leng-1; i=i+1) begin
             @ (posedge hclk);
             while (hready==1'b0) @ (posedge hclk);
             hwdata <=  data_burst_wr[start_addr+i];
             haddr  <=  addr+(i+1)*4;
             htrans <=  2'b11; //`htrans_seq;
             while (hready==1'b0) @ (posedge hclk);
         end
         @ (posedge hclk);
         while (hready==0) @ (posedge hclk);
         hwdata <=  data_burst_wr[start_addr+i];
         //hsel   <=  0;
         haddr  <=  0;
         htrans <=  0;
         hburst <=  0;
         hwrite <=  0;
         hsize  <=  0;
         hbusreq <=  1'b0;
         @ (posedge hclk);
         while (hready==0) @ (posedge hclk);
         if (hresp!=2'b00) begin //`hresp_okay
$display($time,, "error: non ok response write");
         end
`ifdef debug
$display($time,, "info: write(%x, %d, %x)", addr, size, data);
`endif
         hwdata <=  0;
         @ (posedge hclk);
     end
endtask
task ahb_write_SIMD_burst;
     input  [31:0] start_addr;
     input  [31:0] addr;
     input  [31:0] leng;
     integer       i;
     begin
         @ (posedge hclk);
         hbusreq <=  1'b1;
         @ (posedge hclk);
         while ((hgrant!==1'b1)||(hready!==1'b1)) @ (posedge hclk);
         haddr  <=  addr;
         htrans <=  2'b10; //`htrans_nonseq;
         if (leng==4)       hburst <=  3'b011; //`hburst_incr4;
         else if (leng==8)  hburst <=  3'b101; //`hburst_incr8;
         else if (leng==16) hburst <=  3'b111; //`hburst_incr16;
         else               hburst <=  3'b001; //`hburst_incr;
         hwrite <=  1'b1; //`hwrite_write;
         hsize  <=  3'b010; //`hsize_word;
         for (i=0; i<leng-1; i=i+1) begin
             @ (posedge hclk);
             while (hready==1'b0) @ (posedge hclk);
             hwdata <=  data_burst_SIMD_wr[start_addr+i];
             haddr  <=  addr+(i+1)*4;
             htrans <=  2'b11; //`htrans_seq;
             while (hready==1'b0) @ (posedge hclk);
         end
         @ (posedge hclk);
         while (hready==0) @ (posedge hclk);
         hwdata <=  data_burst_SIMD_wr[start_addr+i];
         //hsel   <=  0;
         haddr  <=  0;
         htrans <=  0;
         hburst <=  0;
         hwrite <=  0;
         hsize  <=  0;
         hbusreq <=  1'b0;
         @ (posedge hclk);
         while (hready==0) @ (posedge hclk);
         if (hresp!=2'b00) begin //`hresp_okay
$display($time,, "error: non ok response write");
         end
`ifdef debug
$display($time,, "info: write(%x, %d, %x)", addr, size, data);
`endif
         hwdata <=  0;
         @ (posedge hclk);
     end
endtask
endmodule
