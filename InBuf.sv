module InBuf#(
    parameter P_BINDWIDTH=64
    )(
    input clk,
    input nRst,
    input nWe,
    input nCe,
    input [P_BINDWIDTH-1:0] iWriteDataA,
    input [P_BINDWIDTH-1:0] iWriteDataB,
    input iSelect,
    output [P_BINDWIDTH-1:0] oInData,

    input iComputeDone, //in top ,likely to deal with resident conv 
    input [31:0] iInstruction,
    input [9:0] iActSramReadCenterAddr,

    input zeroMask,
    input [9:0] readAddr
);

wire [P_BINDWIDTH-1:0] DataSelect;

MUX #(
    .P_BINDWIDTH(P_BINDWIDTH)
)u_MUX (
    .iSelect(iSelect),
    .iWriteDataA(iWriteDataA),
    .iWriteDataB(iWriteDataB),
    .DataSelect(DataSelect)
);

BUFAPU #(
    .P_BINDWIDTH(P_BINDWIDTH)
) u_BUFAPU (
    .clk(clk),
    .nRst(nRst),
    .Datain(DataSelect),
    .nWe(nWe),
    .nCe(nCe),
    .oInData(oInData),
    .iComputeDone(iComputeDone),
    .iInstruction(iInstruction),
    .iActSramReadCenterAddr(iActSramReadCenterAddr),
    .zeroMask(zeroMask),
    .readAddr(readAddr),
    .iSelect(iSelect)
);

endmodule

module BUFAPU #(
    parameter P_BINDWIDTH=64
    )(
    input clk,
    input nRst,
    input [P_BINDWIDTH-1:0] Datain,
    input nWe,
    input nCe,
    output reg [P_BINDWIDTH-1:0] oInData,

    input iComputeDone, //in top ,likely to deal with resident conv 
    input [31:0] iInstruction,
    input [9:0] iActSramReadCenterAddr,

    input zeroMask,
    input [9:0] readAddr,

    input iSelect
);

reg [9:0] iActSramReadCenterAddr_r;
reg zeroMask_r;
reg [9:0] readAddr_r;
reg [9:0] readAddr_rr;
reg [31:0] iInstruction_r;
reg iSelect_r;

always @(posedge clk, negedge nRst)
begin
    if(!nRst)
    begin
        iActSramReadCenterAddr_r<='d0;
        zeroMask_r<='d0;
        readAddr_r<='d0;
        readAddr_rr<='b0;
        iInstruction_r<='d0;
        iSelect_r<='d0;
    end
    else
    begin
        iActSramReadCenterAddr_r<=iActSramReadCenterAddr;
        zeroMask_r<=zeroMask;
        readAddr_r<=readAddr;
        readAddr_rr<=readAddr_r;
        iInstruction_r<=iInstruction;
        iSelect_r<=iSelect;
    end
end

reg [P_BINDWIDTH-1:0] rBuf;
reg [1023:0][64:0] resident_sram; //最高位为标志位
integer i;

always @(posedge clk ,negedge nRst)
begin
    if(!nRst)
    begin
        if(!nRst)
        begin
            rBuf<=0;
            for(i=0; i<1024; i=i+1)
            begin
                resident_sram[i]<='d0;
            end
        end  
    end
    else if(iComputeDone=='b1) //完成计算，清空sram
    begin
        for(i=0; i<1024; i=i+1)
        begin
            resident_sram[i]<='d0;
        end
    end
    else
    begin
        casez({iInstruction[30],iSelect})
        2'b0?:
        begin
            if(!nWe)
            begin
                rBuf<=Datain;
            end
            else
            begin
                rBuf<=rBuf;
            end
        end
        2'b11:
        begin
            if(!nWe)
            begin
                rBuf<=Datain;
            end
            else
            begin
                rBuf<=rBuf;
            end
        end
        2'b10:
        begin
            if(!nWe)
            begin
                if(zeroMask==1'b1)
                begin
                    //do nothing ,反正进来的readAddr也不对吧
                end
                else
                begin
                    if(resident_sram[readAddr_r][64]==1'b0) //最高位标志位为0，说明第一次写入/readAddr_r对应的第一个数据
                    begin
                        resident_sram[readAddr_r]<={1'b1,Datain}; //写入数据的同时，将标志位置1
                    end
                    else
                    begin
                        //do nothing, 写过了，此时readAddr来的可能是卷积后的错误数据
                    end
                end
            end
            else
            begin
                //do nothing
            end
        end
        endcase
    end
end

always @(*)
begin
    if(!nCe)
    begin
        casez({iInstruction_r[30],iSelect_r})
        2'b0?: oInData=rBuf;
        2'b11: oInData=rBuf;
        2'b10: //oInData=resident_sram[iActSramReadCenterAddr_r]; //延迟一个周期的地址
        begin
            if(zeroMask_r==1'b1) //事实上残差都是1x1，这个zeroMask似乎是不必要的
            begin
                oInData='b0; //padding
            end
            else
            begin
                oInData=resident_sram[readAddr_rr][63:0]; //延迟2个周期的地址,读数据位
            end
        end
        endcase
    end
    else
    begin
        oInData='b0;
    end
end

endmodule

module MUX #(
    parameter P_BINDWIDTH=64
    )(
    input iSelect,
    input [P_BINDWIDTH-1:0] iWriteDataA,
    input [P_BINDWIDTH-1:0] iWriteDataB,
    output reg  [P_BINDWIDTH-1:0] DataSelect
);

always @(*)
begin
    if(iSelect)
    begin
        DataSelect=iWriteDataB;
    end
    else
    begin
        DataSelect=iWriteDataA;
    end
end

endmodule