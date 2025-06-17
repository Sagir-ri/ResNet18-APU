module WorkSheet #( //this is the final ver
    parameter  P_INSTRUCTION_NUM = 16    
)(
    input clk,
    input nRst,
    input nWe,
    input [3:0] iWriteAddr,
    input [31:0] iWriteData,
    input [3:0] iReadAddr,
    input iAPUReady,
    input iComputeDone,
    output reg oWorkSheetDone,
    output reg [31:0] oWorkSheetData,
    output reg oCtrlnCe,
    output reg [31:0] oInstruction
);

reg  [31:0] r_Instruction [P_INSTRUCTION_NUM - 1:0];
reg [3:0] currentInstrAddress;
reg [P_INSTRUCTION_NUM - 1:0] totalInstrCount;
reg IDEL;


//control totalInstrCount

integer i;

always @(posedge clk ,negedge nRst)
begin
    if(!nRst)
    begin
        /*
        for(i=0;i<P_INSTRUCTION_NUM;i=i+1)
        begin
            r_Instruction[i]<=32'b0;
        end
            */
        totalInstrCount<=0;
    end
    else
    begin
        if(!nWe)
        begin

            r_Instruction[iWriteAddr]<=iWriteData; //write data

            totalInstrCount<=totalInstrCount+1;
        end
        else
        begin
            if(currentInstrAddress==totalInstrCount-1&&iComputeDone==1)
            begin
                totalInstrCount<=0;
            end
            else
            begin
                totalInstrCount<=totalInstrCount; //keep ,avoid latch
            end
        end
    end
end


//slave read data
always @(posedge clk)
begin
    oWorkSheetData <= r_Instruction[iReadAddr];
end
//assign oWorkSheetData = r_Instruction[iReadAddr];


//send instrs to control module
always @(posedge clk ,negedge nRst)
begin
    if(!nRst)
    begin
        oWorkSheetDone<=0;
        oInstruction<=32'b0;
        currentInstrAddress<=0;
        oCtrlnCe<=1;
        IDEL<=1;
    end
    else
    begin
        if(IDEL)
        begin
            if(iAPUReady)
            begin
                oInstruction<=r_Instruction[currentInstrAddress]; //PASS instrs

                currentInstrAddress<=0;
                oCtrlnCe<=0;
                IDEL<=0;
                oWorkSheetDone<=oWorkSheetDone;
            end
            else
            begin
                currentInstrAddress<=currentInstrAddress;
                oCtrlnCe<=oCtrlnCe;
                IDEL<=IDEL;
                oWorkSheetDone<=0;
            end
        end
        else
        begin
            if(currentInstrAddress==totalInstrCount-1&&iComputeDone==1)
            begin
                oWorkSheetDone<=1;
                oInstruction<=0;
                currentInstrAddress<=0;
                oCtrlnCe<=1;
                IDEL<=1;
            end
            else
            begin
                if(iComputeDone)
                begin
                    oInstruction<=r_Instruction[currentInstrAddress+1]; 

                    oWorkSheetDone<=0;
                    currentInstrAddress<=currentInstrAddress+1;
                    oCtrlnCe<=0;
                    IDEL<=0;
                end
                else
                begin
                    oWorkSheetDone<=0;
                    oCtrlnCe<=0;
                    IDEL<=0;

                    oInstruction<=oInstruction;
                    currentInstrAddress<=currentInstrAddress;
                end
            end       
        end
    end
end







endmodule