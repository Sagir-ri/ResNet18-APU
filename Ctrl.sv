module Ctrl #(
    parameter P_BINDWIDTH = 64,
    parameter P_FEATURE_MEMORY_SIZE = 65536
) (
    input clk,
    input nRst,
    input nCe,

    //From Instruction Registerfile
    input [31:0] iInstruction,

    //For ActSRAM
    output reg    [9:0] oActReadCenterAddr,
    output reg                                                    oActReadEn,
    output reg    [                                          1:0] oActKernelSize,
    output reg    [                                          5:0] oActHW,
    output reg    [                                          3:0] oActlogInC,
    output reg [9:0] oActWriteAddr,       //need delay 3 cycle
    output reg                                                 oActWriteEn,         //need delay 3 cycle
    //For InputBuf
    output reg                                                 oInputBufNWe,         //need delay 1 cycle
    output reg                                                 oInputBufSelect,     //need delay 1 cycle

    //For OutSRAM
    output reg    [9:0] oOutReadCenterAddr,
    output reg                                                    oOutReadEn,
    output reg    [                                          1:0] oOutKernelSize,
    output reg    [                                          5:0] oOutHW,
    output reg    [                                          3:0] oOutlogInC,
    output reg [9:0] oOutWriteAddr,       //need delay 3 cycle
    output reg                                                 oOutWriteEn,         //need delay 3 cycle
    //For SIMD
    output reg [                                          4:0] oBNAddr,
    //For ComputeCoreGroup
    output reg [                                          7:0] oWeightAddr,
    output reg                                                 oWeightReadEn,
    output reg [                                          1:0] oAccInstr,           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
    //For WorkSheet to fetch next Instruction
    output reg                                                 oComputeDone
);

reg [1:0] opcode;
reg [1:0] KernelSize;
reg [5:0] in_HW;
reg [8:0] in_c;
reg [8:0] out_c;
reg [1:0] stride1;
reg [1:0] stride2;
reg [7:0] conv1_addr_initial;
reg [4:0] bn_addr_initial;
 
//00_11_101_0110_0111_10_00_00000000_00000

always @(*) //decode
begin
  opcode=iInstruction[31:30];//opcode

  KernelSize=iInstruction[29:28]; //KernelSize

  casex(iInstruction[27:25]) //in_HW
  3'b011:
  begin
    in_HW='d8;
  end
  3'b100:
  begin
    in_HW='d16;
  end
  3'b101:
  begin
    in_HW='d32;
  end
  default:
  begin
    in_HW='d8;
  end
  endcase

  casex(iInstruction[24:21]) //in_c
  4'b0110:
  begin
    in_c='d64;
  end
  4'b0111:
  begin
    in_c='d128;
  end
  4'b1000:
  begin
    in_c='d256;
  end
  default:
  begin
    in_c='d64;
  end
  endcase

  casex(iInstruction[20:17]) //out_c
  4'b0110:
  begin
    out_c='d64;
  end
  4'b0111:
  begin
    out_c='d128;
  end
  4'b1000:
  begin
    out_c='d256;
  end
  default:
  begin
    out_c='d64;
  end
  endcase

  casex(opcode) //stride1
  2'b00:
  begin
    casex(iInstruction[16:15])
    2'b01:
    begin
      stride1='d1;
    end
    2'b10:
    begin
      stride1='d2;
    end
    default:
    begin
      stride1='d1;
    end
    endcase
  end
  2'b01:
  begin
    stride1='d1;
  end
  default:
  begin
    stride1='d1;
  end
  endcase

  casex(opcode) //stride2
  2'b00:
  begin
    stride2='d1;
  end
  2'b01:
  begin
    stride2='d2;
  end
  default:
  begin
    stride2='d1;
  end
  endcase

  conv1_addr_initial=iInstruction[12:5];

  bn_addr_initial=iInstruction[4:0];

end

reg [11:0] totalRound; //HW
reg [11:0] timePerRound; //in_C/64 * out_C/64
reg [11:0] cyclePerTime; //KernelSize

reg [7:0] conv_type;

always @(*) //compute APU cycles
begin
  casex(opcode)
  2'b00: //compute 1
  begin
    casex({in_c ,out_c ,in_HW ,KernelSize ,stride1}) //9 bits ,9 bits ,6 bits ,2 bits ,2 bits
    {9'd64 ,9'd64 ,6'd32 ,2'd3 ,2'd1}: //conv1
    begin
      totalRound='d1024-1'd1;
      timePerRound='d1-1'd1;
      cyclePerTime='d9-1'd1;
      conv_type='d1;
    end
    {9'd64 ,9'd128 ,6'd32 ,2'd3 ,2'd2}: //conv2
    begin
      totalRound='d256-1'd1;
      timePerRound='d2-1'd1;
      cyclePerTime='d9-1'd1;
      conv_type='d2;
    end
    {9'd128 ,9'd128 ,6'd16 ,2'd3 ,2'd1}: //conv3
    begin
      totalRound='d256-1'd1;
      timePerRound='d2-1'd1;
      cyclePerTime='d18-1'd1;
      conv_type='d3;
    end
    {9'd128 ,9'd256 ,6'd16 ,2'd3 ,2'd2}: //conv4
    begin
      totalRound='d64-1'd1;
      timePerRound='d4-1'd1;
      cyclePerTime='d18-1'd1;
      conv_type='d4;
    end
    {9'd256 ,9'd256 ,6'd8 ,2'd3 ,2'd1}: //conv5
    begin
      totalRound='d64-1'd1;
      timePerRound='d4-1'd1;
      cyclePerTime='d36-1'd1;
      conv_type='d5;
    end
    default:
    begin
      totalRound='d1024-1'd1;
      timePerRound='d1-1'd1;
      cyclePerTime='d9-1'd1;
      conv_type='d1;
    end
    endcase
  end
  2'b01:
  begin
    casex({in_c ,out_c ,in_HW ,KernelSize ,stride1}) //9 bits ,9 bits ,6 bits ,2 bits ,2 bits
    {9'd128 ,9'd128 ,6'd16 ,2'd3 ,2'd1}: //conv6 (3+6)
    begin
      totalRound='d256-1'd1;
      timePerRound='d2-1'd1;
      cyclePerTime='d18+1'd1-1'd1;
      conv_type='d6;
    end
    {9'd256 ,9'd256 ,6'd8,2'd3 ,2'd1}: //conv7 (5+7)
    begin
      totalRound='d64-1'd1;
      timePerRound='d4-1'd1;
      cyclePerTime='d38-1'd1;
      conv_type='d7;
    end
    default:
    begin
      totalRound='d256-1'd1;
      timePerRound='d2-1'd1;
      cyclePerTime='d18+1'd1-1'd1;
      conv_type='d6;
    end
    endcase
  end
  default:
  begin
    totalRound='d1024-1'd1;
    timePerRound='d1-1'd1;
    cyclePerTime='d9-1'd1;
    conv_type='d1;
  end
  endcase
end
  
parameter IDLE=1'b0;
parameter CONV=1'b1;
reg state;
reg [11:0] cycle;
reg [11:0] t;
reg [11:0] round;
reg pingpong; //switch ActSRAM to OutSRAM or OutSRAM to ActSRAM

reg [11:0] cycle_r ,cycle_r_r ,cycle_r_r_r;



reg    [9:0] ReadCenterAddr;
reg    [9:0] readResidentAddr;
reg                                                    ReadEn;
wire    [                                          1:0] kernelsize;
wire   [                                          5:0] HW;
reg    [                                          3:0] logInC;

assign kernelsize=KernelSize;
assign HW=in_HW;


always @(*)
begin
  casex(in_c)
  'd64: logInC='d6;
  'd128: logInC='d7;
  'd256: logInC='d8;
  default: logInC='d6;
  endcase
end

reg [9:0] WriteAddr;      //need delay 3 cycle
reg [9:0] WriteAddr_r; 
reg [9:0] WriteAddr_r_r; 
reg [9:0] WriteAddr_r_r_r; 
reg                                                 WriteEn;         //need delay 3-1 cycle for sampling WriteAddr
reg                                                 WriteEn_r; 
reg                                                 WriteEn_r_r; 
//reg                                                 WriteEn_r_r_r; 
//For InputBuf
reg                                                 InputBufNWe;         //need delay 1 cycle
reg                                                 InputBufNWe_r;
reg                                                 InputBufSelect;     //need delay 1 cycle
reg                                                 InputBufSelect_r; 

//For SIMD
reg [                                          4:0] BNAddr; //need de;ay 2cycle
reg [                                          4:0] BNAddr_r;
reg [                                          4:0] BNAddr_r_r;
reg [                                          4:0] BNAddr_r_r_r;
//For ComputeCoreGroup
reg [                                          7:0] WeightAddr;
reg                                                 WeightReadEn;
reg [                                          1:0] AccInstr;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
reg [                                          1:0] AccInstr_r;
reg [                                          1:0] AccInstr_r_r;
//For WorkSheet to fetch next Instruction
reg                                                 ComputeDone;

reg pingpong_r;
reg pingpong_r_r;
reg pingpong_r_r_r;
reg pingpong_r_r_r_r;

always @(posedge clk ,negedge nRst) //delay part
begin
  if(!nRst)
  begin
    WriteAddr_r<='b0; 
    WriteAddr_r_r<='b0; 
    WriteAddr_r_r_r<='b0; 

    WriteEn_r<='b0; 
    WriteEn_r_r<='b0; 
    //WriteEn_r_r_r<='b0; 

    InputBufNWe_r<='b0;
    InputBufSelect_r<='b0; 

    AccInstr_r<='b0;
    AccInstr_r_r<='b0;

    pingpong_r<='b0;
    pingpong_r_r<='b0;
    pingpong_r_r_r<='b0;
    pingpong_r_r_r_r<='b0;

    BNAddr_r<='b0;
    BNAddr_r_r<='b0;
    BNAddr_r_r_r<='b0;

    cycle_r<='b0;
    cycle_r_r<='b0;
    cycle_r_r_r<='b0;
  end
  else
  begin
      WriteAddr_r<=WriteAddr; 
      WriteAddr_r_r<=WriteAddr_r; 
      WriteAddr_r_r_r<=WriteAddr_r_r; 

      WriteEn_r<=WriteEn; 
      WriteEn_r_r<=WriteEn_r; 
      //WriteEn_r_r_r<=WriteEn_r_r; 

      InputBufNWe_r<=InputBufNWe;
      InputBufSelect_r<=InputBufSelect; 

      AccInstr_r<=AccInstr;
      AccInstr_r_r<=AccInstr_r;

      pingpong_r<=pingpong;
      pingpong_r_r<=pingpong_r;
      pingpong_r_r_r<=pingpong_r_r;
      pingpong_r_r_r_r<=pingpong_r_r_r;

      BNAddr_r<=BNAddr;
      BNAddr_r_r<=BNAddr_r;
      BNAddr_r_r_r<=BNAddr_r_r;

      cycle_r<=cycle;
      cycle_r_r<=cycle_r;
      cycle_r_r_r<=cycle_r_r;
  end
end

always @(*) //final output 
begin
  if(opcode=='b0)
  begin
    if(!pingpong_r_r_r_r)
    begin
      
      
      oActWriteAddr='b0;       //need delay 3 cycle
      oActWriteEn='b0;         //need delay 3-1 cycle


      
      
      oOutWriteAddr=WriteAddr_r_r_r;       //need delay 3 cycle
      oOutWriteEn=WriteEn_r_r;         //need delay 3-1  cycle
    end
    else
    begin
      
      
      oActWriteAddr=WriteAddr_r_r_r;       //need delay ？ cycle
      oActWriteEn=WriteEn_r_r;         //need delay ？ cycle
    
      
      
      oOutWriteAddr='b0;       //need delay 3 cycle
      oOutWriteEn='b0;         //need delay 3-1 cycle
    end

    if(!pingpong) //ActSRAM to OutSRAM
    begin
      //For ActSRAM
      oActReadCenterAddr=ReadCenterAddr;
      oActReadEn=ReadEn;

      //For OutSRAM
      oOutReadCenterAddr='b0;
      oOutReadEn='b0;

      oActKernelSize=kernelsize;
      oActHW=HW;
      oActlogInC=logInC;

      oOutKernelSize='b1;
      oOutHW='b0;
      oOutlogInC='b0;

      //For InputBuf
      oInputBufNWe=InputBufNWe_r;         //need delay 1 cycle
      oInputBufSelect=InputBufSelect_r;     //need delay 1 cycle

      //For SIMD
      oBNAddr=BNAddr_r_r_r;
      //For ComputeCoreGroup
      oWeightAddr=WeightAddr;
      oWeightReadEn=WeightReadEn;
      oAccInstr=AccInstr_r_r;           // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
      //For WorkSheet to fetch next Instruction
      oComputeDone=ComputeDone;
    end
    else //OutSRAM to ActSRAM
    begin
      //For ActSRAM
      oActReadCenterAddr='b0;
      oActReadEn='b0;

      //For OutSRAM
      oOutReadCenterAddr=ReadCenterAddr;
      oOutReadEn=ReadEn;

      oActKernelSize='b1;
      oActHW='b0;
      oActlogInC='b0;

      oOutKernelSize=kernelsize;
      oOutHW=HW;
      oOutlogInC=logInC;

      //For InputBuf
      oInputBufNWe=InputBufNWe_r;         //need delay ？ cycle
      oInputBufSelect=InputBufSelect_r;     //need delay ？ cycle

      //For SIMD
      oBNAddr=BNAddr_r_r_r;

      //For ComputeCoreGroup
      oWeightAddr=WeightAddr;
      oWeightReadEn=WeightReadEn;
      oAccInstr=AccInstr_r_r;           // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
      //For WorkSheet to fetch next Instruction
      oComputeDone=ComputeDone;
    end
  end
  else //if opcode=='b1 ResNet
  begin
    if(conv_type=='d6)
    begin
      if(!pingpong_r_r_r_r)
      begin
        
        
        oActWriteAddr='b0;       //need delay 3 cycle
        oActWriteEn='b0;         //need delay 3-1 cycle


        
        
        oOutWriteAddr=WriteAddr_r_r_r;       //need delay 3 cycle
        oOutWriteEn=WriteEn_r_r;         //need delay 3-1  cycle
      end
      else
      begin
        
        
        oActWriteAddr=WriteAddr_r_r_r;       //need delay ？ cycle
        oActWriteEn=WriteEn_r_r;         //need delay ？ cycle
      
        
        
        oOutWriteAddr='b0;       //need delay 3 cycle
        oOutWriteEn='b0;         //need delay 3-1 cycle
      end //emmmmmmmmmmmmm

      if(!pingpong) //ActSRAM to OutSRAM
      begin
        //For ActSRAM
        oActReadCenterAddr=ReadCenterAddr;
        oActReadEn=(cycle_r_r!=(cyclePerTime-'d2)) ? ReadEn : 'b0;

        //For OutSRAM
        oOutReadCenterAddr=readResidentAddr;
        oOutReadEn= (state == IDLE) ? 'b0 : !oActReadEn;

        oActKernelSize=kernelsize;
        oActHW=HW;
        oActlogInC=logInC;

        oOutKernelSize='d1;
        oOutHW='d32;
        oOutlogInC='d6;

        //For InputBuf
        if(cycle_r_r==(cyclePerTime-'d1))
        begin
          oInputBufNWe=InputBufNWe_r;         //need delay 1 cycle
          oInputBufSelect=!InputBufSelect_r;     //need delay 1 cycle
        end
        else
        begin
          oInputBufNWe=InputBufNWe_r;         //need delay 1 cycle
          oInputBufSelect=InputBufSelect_r;     //need delay 1 cycle
        end

        //For SIMD
        oBNAddr=BNAddr_r_r_r;
        //For ComputeCoreGroup
        oWeightAddr=WeightAddr;
        oWeightReadEn=WeightReadEn;
        oAccInstr=AccInstr_r_r;           // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
        //For WorkSheet to fetch next Instruction
        oComputeDone=ComputeDone;
      end
      else //OutSRAM to ActSRAM //unlikely situation
      begin
        

        //For OutSRAM
        oOutReadCenterAddr=ReadCenterAddr;
        oOutReadEn=(cycle_r_r!=(cyclePerTime-'d2))  ? ReadEn : 'b0;

        //For ActSRAM
        oActReadCenterAddr=readResidentAddr;
        oActReadEn= (state == IDLE) ? 'b0 : !oOutReadEn;

        oActKernelSize='d1;
        oActHW='d32;
        oActlogInC='d6;

        oOutKernelSize=kernelsize;
        oOutHW=HW;
        oOutlogInC=logInC;

        //For InputBuf
        if(cycle_r_r==(cyclePerTime-'d1))
        begin
          oInputBufNWe=InputBufNWe_r;         //need delay 1 cycle
          oInputBufSelect=!InputBufSelect_r;     //need delay 1 cycle
        end
        else
        begin
          oInputBufNWe=InputBufNWe_r;         //need delay 1 cycle
          oInputBufSelect=InputBufSelect_r;     //need delay 1 cycle
        end

        //For SIMD
        oBNAddr=BNAddr_r_r_r;

        //For ComputeCoreGroup
        oWeightAddr=WeightAddr;
        oWeightReadEn=WeightReadEn;
        oAccInstr=AccInstr_r_r;           // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
        //For WorkSheet to fetch next Instruction
        oComputeDone=ComputeDone;
      end
    end
    else //conv_type==7
    begin
      if(!pingpong_r_r_r_r)
      begin
        
        
        oActWriteAddr='b0;       //need delay 3 cycle
        oActWriteEn='b0;         //need delay 3-1 cycle


        
        
        oOutWriteAddr=WriteAddr_r_r_r;       //need delay 3 cycle
        oOutWriteEn=WriteEn_r_r;         //need delay 3-1  cycle
      end
      else
      begin
        
        
        oActWriteAddr=WriteAddr_r_r_r;       //need delay ？ cycle
        oActWriteEn=WriteEn_r_r;         //need delay ？ cycle
      
        
        
        oOutWriteAddr='b0;       //need delay 3 cycle
        oOutWriteEn='b0;         //need delay 3-1 cycle
      end //emmmmmmmmmmmmm

      if(!pingpong) //ActSRAM to OutSRAM
      begin
        //For ActSRAM
        oActReadCenterAddr=ReadCenterAddr;
        oActReadEn=((cycle_r_r!=(cyclePerTime-'d2))&&(cycle_r_r!=(cyclePerTime-'d3))) ? ReadEn : 'b0; //unchanged

        //For OutSRAM
        oOutReadCenterAddr=readResidentAddr;
        oOutReadEn=(state == IDLE) ? 'b0 : !oActReadEn;

        oActKernelSize=kernelsize;
        oActHW=HW;
        oActlogInC=logInC;

        oOutKernelSize='d1;
        oOutHW='d16;
        oOutlogInC='d7;

        //For InputBuf
        if((cycle_r==cyclePerTime)||(cycle_r==cyclePerTime-'d1))
        begin
          oInputBufNWe=InputBufNWe_r;         //need delay 1 cycle
          oInputBufSelect=!InputBufSelect_r;     //need delay 1 cycle
        end
        else
        begin
          oInputBufNWe=InputBufNWe_r;         //need delay 1 cycle
          oInputBufSelect=InputBufSelect_r;     //need delay 1 cycle
        end

        //For SIMD
        oBNAddr=BNAddr_r_r_r;
        //For ComputeCoreGroup
        oWeightAddr=WeightAddr;
        oWeightReadEn=WeightReadEn;
        oAccInstr=AccInstr_r_r;           // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
        //For WorkSheet to fetch next Instruction
        oComputeDone=ComputeDone;
      end
      else //OutSRAM to ActSRAM //unlikely situation
      begin


        //For OutSRAM
        oOutReadCenterAddr=ReadCenterAddr;
        oOutReadEn=((cycle_r_r!=(cyclePerTime-'d2))&&(cycle_r_r!=(cyclePerTime-'d3))) ? ReadEn : 'b0;

        //For ActSRAM
        oActReadCenterAddr=readResidentAddr;
        oActReadEn=(state == IDLE) ? 'b0 : !oOutReadEn;

        oActKernelSize='d1;
        oActHW='d16;
        oActlogInC='d7;

        oOutKernelSize=kernelsize;
        oOutHW=HW;
        oOutlogInC=logInC;

        //For InputBuf
        if((cycle_r==cyclePerTime)||(cycle_r==cyclePerTime-'d1))
        begin
          oInputBufNWe=InputBufNWe_r;         //need delay 1 cycle
          oInputBufSelect=!InputBufSelect_r;     //need delay 1 cycle
        end
        else
        begin
          oInputBufNWe=InputBufNWe_r;         //need delay 1 cycle
          oInputBufSelect=InputBufSelect_r;     //need delay 1 cycle
        end

        //For SIMD
        oBNAddr=BNAddr_r_r_r;

        //For ComputeCoreGroup
        oWeightAddr=WeightAddr;
        oWeightReadEn=WeightReadEn;
        oAccInstr=AccInstr_r_r;           // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
        //For WorkSheet to fetch next Instruction
        oComputeDone=ComputeDone;
      end
    end
  end

  
end

always @(posedge clk or negedge nRst) 
  begin
    if (!nRst) 
    begin
      state<=IDLE;

      //For Timing
      cycle<='b0;
      t<='b0;
      round<='b0;

      //For Pingpong
      pingpong<='b0;

      readResidentAddr<='b0;
      ReadCenterAddr<='b0;
      ReadEn<='b0;
      WriteAddr<='b0;      //need delay 3 cycle
      WriteEn<='b0;         //need delay 3 cycle

      //For InputBuf
      InputBufNWe<='b1;         //need delay 1 cycle
      InputBufSelect<='b0;     //need delay 1 cycle


      //For SIMD
      BNAddr<=bn_addr_initial;
      //For ComputeCoreGroup
      WeightAddr<=conv1_addr_initial;
      WeightReadEn<='b0;
      AccInstr<='b0;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value

      //For WorkSheet to fetch next Instruction
      ComputeDone<='b0;
    end 
    else 
    begin
      case (state)
        IDLE: 
        begin

          if((!nCe)&&(!oComputeDone))
          begin
            state<=CONV;

            //For Timing
            cycle<='b0;
            t<='b0;
            round<='b0;

            //For Pingpong
            //pingpong<='b0;
            
            readResidentAddr<='b0;
            ReadCenterAddr<='b0;
            ReadEn<='b1;
            WriteAddr<='b0;      //need delay 3 cycle
            WriteEn<='b0;         //need delay 3 cycle

            //For InputBuf
            InputBufNWe<='b0;         //need delay 1 cycle
            InputBufSelect<=pingpong;     //need delay 1 cycle


            //For SIMD
            BNAddr<=bn_addr_initial;
            //For ComputeCoreGroup
            WeightAddr<=conv1_addr_initial;
            WeightReadEn<='b1;
            AccInstr<='b01;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value

            //For WorkSheet to fetch next Instruction
            ComputeDone<='b0;
          end
          else
          begin
            state<=IDLE;

            //For Timing
            cycle<='b0;
            t<='b0;
            round<='b0;

            //For Pingpong
            //pingpong<='b0;
            
            readResidentAddr<='b0;
            ReadCenterAddr<='b0;
            ReadEn<='b0;
            WriteAddr<='b0;      //need delay 3 cycle
            WriteEn<='b0;         //need delay 3 cycle

            //For InputBuf
            InputBufNWe<='b1;         //need delay 1 cycle
            InputBufSelect<=InputBufSelect;     //need delay 1 cycle


            //For SIMD
            BNAddr<=bn_addr_initial;
            //For ComputeCoreGroup
            WeightAddr<=conv1_addr_initial;
            WeightReadEn<='b0;
            AccInstr<='b0;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value

            //For WorkSheet to fetch next Instruction
            ComputeDone<='b0;
          end
          
        end
        CONV: 
        begin  // Normal Conv1
          if (round < totalRound) 
          begin
            if (t < timePerRound) 
            begin
              if (cycle < cyclePerTime) 
              begin

                cycle<=cycle+1'b1;
                
                    ReadCenterAddr<=ReadCenterAddr;
                    readResidentAddr<=readResidentAddr;

                    
                    ReadEn<='b1;
                    WriteAddr<=WriteAddr;      //need delay 3 cycle
                    WriteEn<='b0;         //need delay 3 cycle
                
                    //For InputBuf
                    InputBufNWe<='b0;         //need delay 1 cycle
                    InputBufSelect<=InputBufSelect;     //need delay 1 cycle
          
                    //For SIMD
                    BNAddr<=BNAddr;

                    //For ComputeCoreGroup
                    WeightAddr<=WeightAddr+1'b1;
                    WeightReadEn<='b1;
                    AccInstr<='b10;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
          
                    //For WorkSheet to fetch next Instruction
                    ComputeDone<='b0;
              end 
              else if (cycle == cyclePerTime) 
              begin  // When finish computing current conv kernel, slide to next kernel

                cycle<=0;
                t<=t+1;

                    ReadCenterAddr<=ReadCenterAddr;
                    readResidentAddr<=readResidentAddr;
                    ReadEn<='b1;
                    WriteAddr<=WriteAddr+1'b1;      //need delay 3 cycle
                    WriteEn<='b1;         //need delay 3 cycle
          
                    //For InputBuf
                    InputBufNWe<='b0;         //need delay 1 cycle
                    InputBufSelect<=InputBufSelect;     //need delay 1 cycle
          
                    //For SIMD
                    BNAddr<=BNAddr+1'b1;

                    //For ComputeCoreGroup
                    WeightAddr<=WeightAddr+1'b1;
                    WeightReadEn<='b1;
                    AccInstr<='b01;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
          
                    //For WorkSheet to fetch next Instruction
                    ComputeDone<='b0;
                
              end 
              else 
              begin
                $display("Wrong computing cycle: %d", cycle);
              end
            end 
            else if (t == timePerRound) 
            begin  // start next input window, reset weight address
              if (cycle < cyclePerTime) 
              begin
                
                cycle<=cycle+1'b1;

                  ReadCenterAddr<=ReadCenterAddr;
                  readResidentAddr<=readResidentAddr;

                    ReadEn<='b1;
                    WriteAddr<=WriteAddr;      //need delay 3 cycle
                    WriteEn<='b0;         //need delay 3 cycle
          
                    //For InputBuf
                    InputBufNWe<='b0;         //need delay 1 cycle
                    InputBufSelect<=InputBufSelect;     //need delay 1 cycle
          
                    //For SIMD
                    BNAddr<=BNAddr;

                    //For ComputeCoreGroup
                    WeightAddr<=WeightAddr+1'b1;
                    WeightReadEn<='b1;
                    AccInstr<='b10;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
          
                    //For WorkSheet to fetch next Instruction
                    ComputeDone<='b0;

                
              end 
              else if (cycle == cyclePerTime) 
              begin  // When finish 1 round for single pixel, slide to next window
                
                //迭代readCenterAddr和readResidentAddr
                cycle<=0;
                t<=0;
                round<=round+1'b1;


                    if(stride1=='b1)
                    begin
                      ReadCenterAddr<=ReadCenterAddr+stride1*(in_c/64);
                    end
                    else //stride1=='b2
                    begin
                      if((ReadCenterAddr+(in_c/64)+(in_c/64))%((in_HW*(in_c/64)))==0) //stride1==2换行 //FP有port iDepth，所以不用在此处迭代输入像素的通道组
                      begin
                        ReadCenterAddr<=ReadCenterAddr+(in_c/64)+(in_c/64)+in_HW*(in_c/64);
                      end
                      else if((ReadCenterAddr)%(in_c/64)==0) //move to next pixel by stride1 //FP有port iDepth，所以不用在此处迭代输入像素的通道组
                      begin
                        ReadCenterAddr<=ReadCenterAddr+(in_c/64)+(in_c/64);
                      end
                      /*
                      else //move to next in_channel in this pixel
                      begin
                        ReadCenterAddr<=ReadCenterAddr+1;
                      end
                        */
                    end

                    if(conv_type=='d6) //sample conv6 in ActSRAM
                    begin
                      if((readResidentAddr+'d2)%('d32)==0) //换行 //第一行最后一个readaddr应该是62
                      begin
                        readResidentAddr<=readResidentAddr+'d2+'d32;
                      end
                      else
                      begin
                        readResidentAddr<=readResidentAddr+'d2;
                      end
                    end
                    

                    if(conv_type=='d7) //sample conv7 in ActSRAM
                    begin
                      if((readResidentAddr+'d2+'d2)%32==0) //换行 //
                      begin
                        readResidentAddr<=readResidentAddr+'d2+'d2+'d32;
                      end
                      else
                      begin
                        readResidentAddr<=readResidentAddr+'d4;
                      end
                    end

                    ReadEn<='b1; 
                    WriteAddr<=WriteAddr+1'b1;      //need delay 3 cycle
                    WriteEn<='b1;         //need delay 3 cycle
          
                    //For InputBuf
                    InputBufNWe<='b0;         //need delay 1 cycle
                    InputBufSelect<=InputBufSelect;     //need delay 1 cycle
          
                    //For SIMD
                    BNAddr<=bn_addr_initial;

                    //For ComputeCoreGroup
                    WeightAddr<=conv1_addr_initial;
                    WeightReadEn<='b1;
                    AccInstr<='b01;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
          
                    //For WorkSheet to fetch next Instruction
                    ComputeDone<='b0;
                
                
              end 
              else 
              begin
                $display("Wrong computing cycle: %d", cycle);
              end
            end 
            else 
            begin
              $display("Wrong computing time: %d", t);
            end
          end 
          else if (round == totalRound) 
          begin  // Last round
            if (t < timePerRound) 
            begin
              if (cycle < cyclePerTime) 
              begin

                  cycle<=cycle+1'b1;

                    ReadCenterAddr<=ReadCenterAddr;
                    readResidentAddr<=readResidentAddr;
                    

                    ReadEn<='b1;
                    WriteAddr<=WriteAddr;      //need delay 3 cycle
                    WriteEn<='b0;         //need delay 3 cycle
          
                    //For InputBuf
                    InputBufNWe<='b0;         //need delay 1 cycle
                    InputBufSelect<=InputBufSelect;     //need delay 1 cycle
          
                    //For SIMD
                    BNAddr<=BNAddr;

                    //For ComputeCoreGroup
                    WeightAddr<=WeightAddr+1'b1;
                    WeightReadEn<='b1;
                    AccInstr<='b10;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
          
                    //For WorkSheet to fetch next Instruction
                    ComputeDone<='b0;
                
              end 
              else if (cycle == cyclePerTime) 
              begin  // When finish computing current conv kernel, slide to next kernel
                cycle<=0;
                t<=t+1;

                    ReadCenterAddr<=ReadCenterAddr;
                    readResidentAddr<=readResidentAddr;
                    ReadEn<='b1;
                    WriteAddr<=WriteAddr+1'b1;      //need delay 3 cycle
                    WriteEn<='b1;         //need delay 3 cycle
          
                    //For InputBuf
                    InputBufNWe<='b0;         //need delay 1 cycle
                    InputBufSelect<=InputBufSelect;     //need delay 1 cycle
          
                    //For SIMD
                    BNAddr<=BNAddr+1'b1;

                    //For ComputeCoreGroup
                    WeightAddr<=WeightAddr+1'b1;
                    WeightReadEn<='b1;
                    AccInstr<='b01;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
          
                    //For WorkSheet to fetch next Instruction
                    ComputeDone<='b0;
               
              end 
              else 
              begin
                $display("Wrong computing cycle: %d", cycle);
              end
            end 
            else if (t == timePerRound) 
            begin  // Last time
              if (cycle < cyclePerTime) 
              begin
                cycle<=cycle+1'b1;

                   
                    ReadCenterAddr<=ReadCenterAddr;
                    readResidentAddr<=readResidentAddr;

                    ReadEn<='b1;
                    WriteAddr<=WriteAddr;      //need delay 3 cycle
                    WriteEn<='b0;         //need delay 3 cycle
          
                    //For InputBuf
                    InputBufNWe<='b0;         //need delay 1 cycle
                    InputBufSelect<=InputBufSelect;     //need delay 1 cycle
          
                    //For SIMD
                    BNAddr<=BNAddr;

                    //For ComputeCoreGroup
                    WeightAddr<=WeightAddr+1'b1;
                    WeightReadEn<='b1;
                    AccInstr<='b10;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
          
                    //For WorkSheet to fetch next Instruction
                    ComputeDone<='b0;

               
              end 
              else if (cycle == cyclePerTime) 
              begin  // Last cycle for current conv layer
                
                pingpong         <= !pingpong;  //switch pingpong ram control after each Conv operation
                state            <= IDLE; 

                cycle<=0;
                t<=0;
                round<=0;


                    ReadCenterAddr<='b0;
                    readResidentAddr<='b0;
                    ReadEn<='b0;

                    WriteAddr<='b0;      //need delay 3 cycle
                    WriteEn<='b1;         //need delay 3 cycle
          
                    //For InputBuf
                    InputBufNWe<='b1;         //need delay 1 cycle
                    InputBufSelect<=InputBufSelect;     //need delay 1 cycle
          
                    //For SIMD
                    BNAddr<=bn_addr_initial;

                    //For ComputeCoreGroup
                    WeightAddr<=conv1_addr_initial;
                    WeightReadEn<='b0;
                    AccInstr<='b00;           //delay 2 cycle // 00 for reset, 01 for assign value, 10 for accumulate, 11 for hold on value
          
                    //For WorkSheet to fetch next Instruction
                    ComputeDone<='b1;

                
              end 
              else 
              begin
                $display("Wrong computing cycle: %d", cycle);
              end
            end 
            else 
            begin
              $display("Wrong computing time: %d", t);
            end
          end 
          else 
          begin
            $display("Wrong computing round: %d", round);
          end
        end
        default: 
        begin
          $display("Wrong working state: %d", state);
        end
      endcase
    end
 end


endmodule
