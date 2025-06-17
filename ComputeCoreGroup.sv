module ComputeCoreGroup #(
    parameter P_GROUP = 64,
    parameter P_GROUP_LOG2 = 6,
    parameter P_WORDS_WE =256,
    parameter P_BITWIDTH_WE =64,
    parameter P_ADDRWIDTH_WE = 8,
    parameter P_INNUM_MUL = P_BITWIDTH_WE,
    parameter P_INBITWIDTH_MUL = 1,
    parameter P_OUTBITWIDTH_MUL = 1,
    parameter P_INNUM_ADD = P_INNUM_MUL,
    parameter P_INBITWIDTH_ADD = P_OUTBITWIDTH_MUL,
    parameter P_STAGES_ADD = 6,
    parameter P_OUTBITWIDTH_ADD = P_INBITWIDTH_ADD+P_STAGES_ADD,
    parameter P_INBITWIDTH_ACC = 7,
    parameter P_OUTBITWIDTH_ACC = 12
)(
    input clk,
    input nRst,
    input [P_BITWIDTH_WE-1:0] weightData,
    input [P_ADDRWIDTH_WE-1:0] weightReadAddr,
    input [P_ADDRWIDTH_WE-1:0] weightWriteAddr,
    input [P_GROUP_LOG2-1:0] weightWriteSelect,
    input nWeightCe,
    input nWeightWe,
    input enableBuf,
    input [P_INNUM_MUL-1:0][P_INBITWIDTH_MUL-1:0] actData,
    input [1:0] accInst,
    output [P_BITWIDTH_WE-1:0] oWeightData,
    output [P_GROUP-1:0][P_OUTBITWIDTH_ACC-1:0] outData
);

wire [P_GROUP-1:0][P_BITWIDTH_WE-1:0] oWeightData_Group;

genvar index;
generate
    for(index=0;index<P_GROUP;index=index+1)
    begin: Group

        wire nWeightSelect;
        assign nWeightSelect = (weightWriteSelect != index);

        ComputeCore #(
            .P_WORDS_WE(P_WORDS_WE),
            .P_BITWIDTH_WE(P_BITWIDTH_WE),
            .P_ADDRWIDTH_WE(P_ADDRWIDTH_WE),
            .P_INNUM_MUL(P_INNUM_MUL),
            .P_INBITWIDTH_MUL(P_INBITWIDTH_MUL),
            .P_OUTBITWIDTH_MUL(P_OUTBITWIDTH_MUL),
            .P_INNUM_ADD(P_INNUM_ADD),
            .P_INBITWIDTH_ADD(P_INBITWIDTH_ADD),
            .P_STAGES_ADD(P_STAGES_ADD),
            .P_OUTBITWIDTH_ADD(P_OUTBITWIDTH_ADD),
            .P_INBITWIDTH_ACC(P_INBITWIDTH_ACC),
            .P_OUTBITWIDTH_ACC(P_OUTBITWIDTH_ACC)
        )u_ComputeCore (
            .clk(clk),
            .nRst(nRst),
            .weightData(weightData),
            .weightReadAddr(weightReadAddr),
            .weightWriteAddr(weightWriteAddr),
            .nWeightCe(nWeightCe),
            .nWeightWe(nWeightWe | nWeightSelect),
            .enableBuf(enableBuf),
            .actData(actData),
            .accInst(accInst),
            .oWeightData(oWeightData_Group[index]),
            .outData(outData[index])
        );

        assign oWeightData=oWeightData_Group[index];
    end
endgenerate



endmodule


module ComputeCore #(
    parameter P_WORDS_WE =256,
    parameter P_BITWIDTH_WE =64,
    parameter P_ADDRWIDTH_WE = 8,
    parameter P_INNUM_MUL = P_BITWIDTH_WE,
    parameter P_INBITWIDTH_MUL = 1,
    parameter P_OUTBITWIDTH_MUL = 1,
    parameter P_INNUM_ADD = P_INNUM_MUL,
    parameter P_INBITWIDTH_ADD = P_OUTBITWIDTH_MUL,
    parameter P_STAGES_ADD = 6,
    parameter P_OUTBITWIDTH_ADD = P_INBITWIDTH_ADD+P_STAGES_ADD,
    parameter P_INBITWIDTH_ACC = 7,
    parameter P_OUTBITWIDTH_ACC = 12
)(
    input clk,
    input nRst,
    input [P_BITWIDTH_WE-1:0] weightData,
    input [P_ADDRWIDTH_WE-1:0] weightReadAddr,
    input [P_ADDRWIDTH_WE-1:0] weightWriteAddr,
    input nWeightCe,
    input nWeightWe,
    input enableBuf,
    input [P_INNUM_MUL-1:0][P_INBITWIDTH_MUL-1:0] actData,
    input [1:0] accInst,
    output [P_BITWIDTH_WE-1:0] oWeightData,
    output [P_OUTBITWIDTH_ACC-1:0] outData
);

reg [P_BITWIDTH_WE-1 : 0] WeightSRAM_oDataa;
assign oWeightData = WeightSRAM_oDataa; //?

WeightSRAM #(
    .P_WORDS(P_WORDS_WE),
    .P_BITWIDTH(P_BITWIDTH_WE),
    .P_ADDRWIDTH(P_ADDRWIDTH_WE)
) u_WeightSRAM (
    .clk(clk),
    .iData(weightData),
    .iAddra(weightReadAddr),
    .iAddrb(weightWriteAddr),
    .nCe(nWeightCe),
    .nWe(nWeightWe),
    .oDataa(WeightSRAM_oDataa)
);

reg [P_INNUM_MUL-1:0] WeightBuffer_oData;


WeightBuffer #(
    .P_INNUM(P_INNUM_MUL)
) u_WeightBuffer (
    .clk(clk),
    .nRst(nRst),
    .enable(enableBuf),
    .iData(WeightSRAM_oDataa),
    .oData(WeightBuffer_oData)
);

reg [P_INNUM_MUL-1:0] Multiplier_oData;

Multiplier #(
    .P_INNUM(P_INNUM_MUL),
    .P_INBITWIDTH(P_INBITWIDTH_MUL),
    .P_OUTBITWIDTH(P_OUTBITWIDTH_MUL)
) u_Multiplier (
    .iDataA(WeightBuffer_oData),
    .iDataB(actData),
    .oData(Multiplier_oData)
);

reg [P_OUTBITWIDTH_ADD-1:0] AdderTree_oData;

AdderTree #(
    .P_INNUM(P_INNUM_ADD),
    .P_INBITWIDTH(P_INBITWIDTH_ADD),
    .P_STAGES (P_STAGES_ADD),
    .P_OUTBITWIDTH(P_OUTBITWIDTH_ADD )
) u_AdderTree (
    .iData(Multiplier_oData),
    .oData(AdderTree_oData)
);


Accumulator #(
    .P_INBITWIDTH(P_INBITWIDTH_ACC),
    .P_OUTBITWIDTH(P_OUTBITWIDTH_ACC)
) u_Accumulator (
    .clk(clk),
    .nRst(nRst),
    .inst(accInst),
    .iData(AdderTree_oData),
    .oData(outData)
);


endmodule



module WeightSRAM #(
    parameter  P_WORDS = 256,
    parameter P_BITWIDTH = 64,
    parameter P_ADDRWIDTH = 8
)(
    input clk,
    input [P_BITWIDTH-1 : 0] iData,
    input [P_ADDRWIDTH-1 : 0] iAddra,
    input [P_ADDRWIDTH-1 : 0] iAddrb,
    input nCe,
    input nWe,
    output reg [P_BITWIDTH-1 : 0] oDataa
);

reg [P_BITWIDTH-1: 0] rData [P_WORDS-1: 0];

always_ff @(posedge clk)
begin
    if(!nCe)
    begin
        oDataa<=rData[iAddra];
    end
    //else keep ,latch
end

always_ff @(posedge clk)
begin
    if(!nWe)
     begin
        rData[iAddrb]<=iData;
    end
    //else do nothing
end

endmodule


module WeightBuffer #(
    parameter P_INNUM = 64
)(
    input clk,
    input nRst,
    input enable,
    input [P_INNUM-1:0] iData,
    output [P_INNUM-1:0] oData
);

reg [P_INNUM-1:0] rData;

always_ff @(posedge clk ,negedge nRst)
begin
    if(!nRst)
    begin
        rData<='b0;
    end
    else
    begin
        if(enable)
        begin
            rData<=iData;
        end
        //else ,rData keep ,latch
    end
end

assign oData=rData;

endmodule

module Multiplier #(
    parameter P_INNUM = 64,
    parameter P_INBITWIDTH = 1,
    parameter P_OUTBITWIDTH = 1
)(
    input [P_INNUM-1:0] iDataA,
    input [P_INNUM-1:0] iDataB,
    output [P_INNUM-1:0][P_OUTBITWIDTH-1:0] oData
);

/*
integer i;
always_comb 
begin
    for(i=0;i<=P_INNUM-1;i=i+1)
    begin
        oData[i]=iDataA[i]^iDataB[i];
    end
end
    */

assign oData=iDataA^iDataB;

endmodule

module  AdderTree #(
    parameter P_INNUM = 64,
    parameter P_INBITWIDTH = 1,
    parameter P_STAGES = 6,
    parameter P_OUTBITWIDTH = P_INBITWIDTH + P_STAGES
)(
    input [P_INNUM-1:0] iData,
    output reg [P_OUTBITWIDTH-1:0] oData
);

reg [P_INNUM-1:0][P_OUTBITWIDTH-1:0] rData;
integer i,j,k;

always_comb
begin
    for(k=0;k<=P_INNUM-1;k=k+1) //initial
    begin
        rData[k]=iData[k];
    end

    
    for(i=1;i<=P_STAGES;i=i+1)
    begin
        for(j=0;j<P_INNUM/(1<<i);j=j+1)
        begin
            rData[j]=rData[j]+rData[j+(P_INNUM/(1<<i))]; //adder
        end
    end
    

    /*
    for(i=1;i<=P_STAGES;i=i+1)
    begin
        for(j=0;j<P_INNUM/($pow(2,i));j=j+2)
        begin
            rData[j]=rData[j]+rData[j+1]; //adder
        end
    end
*/

    //end loop
    oData=rData[0];
end

endmodule


module Accumulator #(
    parameter P_INBITWIDTH = 7,
    parameter P_OUTBITWIDTH = 12
)(
    input clk,
    input nRst,
    input [1:0] inst,
    input [P_INBITWIDTH-1:0] iData,
    output [P_OUTBITWIDTH-1:0] oData
);

reg [P_OUTBITWIDTH-1:0] rData;

always_ff @(posedge clk ,negedge nRst)
begin
    if(!nRst)
    begin
        rData<='b0;
    end
    else
    begin
        casex (inst)
        2'b00: rData<='b0; //IDLE
        2'b01: rData<=iData; //receive data
        2'b10: rData<=iData+rData; //accumulate
        default: rData<=rData; //keep
        endcase
    end
end

assign oData=rData;

endmodule