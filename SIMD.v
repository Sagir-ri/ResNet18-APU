module SIMD #( //this is the final ver
    parameter P_CHANNELS        = 64,
    parameter P_COMPAREWIDTH    = 13,
    parameter P_TOTAL64BN       = 32
)(
    input clk,
    input nRst,
    input nWe,
    input [4:0] iWriteAddr,
    input [5:0]  iChannel,
    input [P_COMPAREWIDTH-1:0]      iWriteData,
    input [P_CHANNELS-1:0][P_COMPAREWIDTH-2:0] iAccData, 
    input [4:0] iAddr,
    output reg [P_CHANNELS-1:0]         oSIMDData,
    output reg [P_COMPAREWIDTH-1:0]     oReadData
);


reg [P_COMPAREWIDTH-1:0] SIMD_Reg [P_TOTAL64BN-1:0][P_CHANNELS-1:0];

//write
integer i, j;
always @(posedge clk, negedge nRst)
 begin
    if (!nRst) 
    begin
        for (i = 0; i < P_TOTAL64BN; i = i + 1) 
        begin
            for (j = 0; j < P_CHANNELS; j = j + 1)
             begin
                SIMD_Reg[i][j] <= 'b0;
            end
        end
    end else if (!nWe) 
    begin  
        SIMD_Reg[iWriteAddr][iChannel] <= iWriteData;
    end
end

//read
//assign oReadData = SIMD_Reg[iAddr][iChannel];
always @(posedge clk)
begin
    oReadData <= SIMD_Reg[iAddr][iChannel];
end

//compute
genvar gv_i;
generate
    for (gv_i = 0; gv_i < P_CHANNELS; gv_i = gv_i + 1) 
    begin : SIMD_channels_generate
        
        wire weightSign = SIMD_Reg[iAddr][gv_i][P_COMPAREWIDTH-1];
        wire [P_COMPAREWIDTH-2:0] compare = SIMD_Reg[iAddr][gv_i][P_COMPAREWIDTH-2:0];
        //wire [P_COMPAREWIDTH-1:0] acc_data = iAccData[gv_i*P_COMPAREWIDTH +: P_COMPAREWIDTH];
        wire SIMD_Temp = (iAccData[gv_i] > compare); 
        
        
        //assign oSIMDData[gv_i] = (weightSign) ? SIMD_Temp : ~SIMD_Temp;

        /*
        always @(posedge clk)
        begin
            oSIMDData[gv_i] <= (weightSign) ? SIMD_Temp : ~SIMD_Temp;
        end
        */

        always @(*)
        begin
            oSIMDData[gv_i] = (weightSign) ? SIMD_Temp : ~SIMD_Temp;
        end
    end
endgenerate



endmodule