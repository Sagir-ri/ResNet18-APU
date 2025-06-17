module FeatureProcessor #( //this is the final ver

    parameter P_FEATURE_MEMORY_SIZE = 65536,

    parameter P_BINDWIDTH = 64

) (

    input clk,

    input nRst,



    // FeatureCtrl Inputs

    input [9:0] iReadCenterAddr,

    input [                                          1:0] iKernelSize,

    input [                                          5:0] inHW,

    input [                                          3:0] iDepth,           // true depth = 64 * iDepth



    // FeatureFetchSRAM Inputs

    input                                                 nWe,

    input [9:0] iWriteAddr,

    input [                              P_BINDWIDTH-1:0] iWriteData,

    input                                                 nCe,



    // Outputs

    output [P_BINDWIDTH-1:0] oFeatureData,
    output reg zeroMask,
    output reg [9:0] readAddr

);
    //registers
    //reg  [9:0] readAddr;
    reg [31:0] countConvCycles;
    reg [31:0] countDepthCycles;
    reg [P_FEATURE_MEMORY_SIZE/P_BINDWIDTH-1:0][P_BINDWIDTH-1:0] featureMemory;
    reg [1:0] rKernelSize;
    //reg zeroMask;// 0 for pass, 1 for zero
    
/*
    Bram_64_1024 featureMemory (
  .clka(clk),            // input wire clka
  .ena(!nWe),              // input wire ena
  .wea(1),              // input wire [0 : 0] wea
  .addra(iWriteAddr),          // input wire [9 : 0] addra
  .dina(iWriteData),            // input wire [63 : 0] dina
  .rstb(!nRst),            // input wire rstb
  .enb(!nCe),              // input wire enb
  .addrb(readAddr),          // input wire [9 : 0] addrb
  .doutb(oFeatureData_r),          // output wire [63 : 0] doutb
  .rsta_busy(rsta_busy),  // output wire rsta_busy
  .rstb_busy(rstb_busy)  // output wire rstb_busy
);
*/   

    // Write featureMemory when nWe is low, and reset it when nWe is high
    integer j;
    always_ff @(posedge clk ,negedge nRst)
    begin
        /*
        if(!nRst)
        begin
            for(j=0;j<=P_FEATURE_MEMORY_SIZE/P_BINDWIDTH-1;j=j+1)
            begin
                featureMemory[j]<='b0;
            end
        end
        else
        begin
            */
            if(!nWe)
            begin
                featureMemory[iWriteAddr]<=iWriteData;
            end
        //end
        
    end

    reg [P_BINDWIDTH-1:0] oFeatureData_r;

    always_ff @(posedge clk)
    begin
        if(!nRst)
        begin
            oFeatureData_r<='b0;
        end
        else
        begin
            if(!nCe)
            begin
                oFeatureData_r<=featureMemory[readAddr];
            end
            else
            begin
                oFeatureData_r<=oFeatureData_r;
            end
        end
         //oFeatureData <= (iKernelSize == 1) ? featureMemory[readAddr] : zeroMask ? 'b0 : featureMemory[readAddr];
    end
    
    assign oFeatureData = (rKernelSize == 1) ? oFeatureData_r : zeroMask ? 'b0 : oFeatureData_r;
    

    // Count countDepthCycles when nCe is low, and reset it when nCe is high
    always_ff @(posedge clk ,negedge nRst)
    begin
        if(!nRst)
        begin
            countDepthCycles<='b0;
        end
        else
        begin
            if(!nCe)
            begin
                if(countDepthCycles<iDepth-1)
                begin
                    countDepthCycles<=countDepthCycles+'b1;
                end
                else
                begin
                    countDepthCycles<='b0;
                end
            end
            else
            begin
                countDepthCycles<='b0;
            end
        end
    end

    // Count countConvCycles when countDepthCycles reaches iDepth - 1, from 0 to 8, and reset it when nCe is high
    always_ff @(posedge clk ,negedge nRst)
    begin
        if(!nRst)
        begin
            countConvCycles<='b0;
        end
        else
        begin
            if(!nCe)
            begin
                if(countConvCycles>=8&&countDepthCycles>=iDepth-1)
                begin
                    countConvCycles<='b0;
                end
                else if(countConvCycles<8&&countDepthCycles>=iDepth-1)
                begin
                    countConvCycles<=countConvCycles+'b1;
                end
                else //keep
                begin
                    countConvCycles<=countConvCycles;
                end
            end
            else
            begin
                countConvCycles<='b0;
            end
        end
    end

    // Calculate readAddr based on countConvCycles and countDepthCycles
    always_comb
    begin
        //if(!nCe)
        //begin
            if (iKernelSize == 'd3) // 3x3 卷积核
            begin
                case(countConvCycles) 
                    'd0: readAddr = iReadCenterAddr + countDepthCycles- inHW*iDepth - iDepth;
                    'd1: readAddr = iReadCenterAddr + countDepthCycles- inHW*iDepth ;
                    'd2: readAddr = iReadCenterAddr + countDepthCycles- inHW*iDepth  + iDepth;
                    'd3: readAddr = iReadCenterAddr + countDepthCycles- iDepth;
                    'd4: readAddr = iReadCenterAddr + countDepthCycles;
                    'd5: readAddr = iReadCenterAddr + countDepthCycles + iDepth;
                    'd6: readAddr = iReadCenterAddr + countDepthCycles + inHW*iDepth - iDepth;
                    'd7: readAddr = iReadCenterAddr + countDepthCycles + inHW*iDepth ;
                    'd8: readAddr = iReadCenterAddr + countDepthCycles + inHW*iDepth  + iDepth;
                    default: readAddr = iReadCenterAddr + countDepthCycles;
                endcase
            end
            else  // 1x1 卷积核
            begin
                readAddr = iReadCenterAddr + countDepthCycles; // 只访问中心点
            end
        //end
       // else
       // begin
            //if(iKernelSize == 'd3)
           // begin
             //   readAddr = iReadCenterAddr + countDepthCycles + inHW*iDepth  + iDepth;
           // end
           // else
          //  begin
             //   readAddr = iReadCenterAddr + countDepthCycles; 
           // end
        //end
    end


    // Update rKernelSize when iKernelSize changes
    always_ff @(posedge clk ,negedge nRst)
    begin
        if(!nRst)
        begin
            rKernelSize<='b0;
        end
        else
        begin
            rKernelSize<=iKernelSize;
        end
    end


    //padding
    // oFeatureData is the output feature data, which is either the original data or 0 if the corresponding pixel is masked out
    always_ff @(posedge clk)
    begin
        if(iKernelSize == 'd3)
        begin
            //zeroMask=0;

            if(iReadCenterAddr==0)//左上角
            begin
                if(countConvCycles=='d0||countConvCycles=='d1||countConvCycles=='d2||countConvCycles=='d3||countConvCycles=='d6) //0,1,2,3,6
                begin
                    zeroMask<=1;
                end
                else
                begin
                    zeroMask<=0;
                end
            end
            else if(iReadCenterAddr==(inHW-1)*iDepth)//右上角
            begin
                if(countConvCycles=='d0||countConvCycles=='d1||countConvCycles=='d2||countConvCycles=='d5||countConvCycles=='d8) //0,1,2,5,8
                begin
                    zeroMask<=1;
                end
                else
                begin
                    zeroMask<=0;
                end
            end
            else if(iReadCenterAddr==(inHW)*(inHW-1)*iDepth)//左下角
            begin
                if(countConvCycles=='d0||countConvCycles=='d3||countConvCycles=='d6||countConvCycles=='d7||countConvCycles=='d8)//0,3,6,7,8
                begin
                    zeroMask<=1;
                end
                else
                begin
                    zeroMask<=0;
                end
            end
            else if(iReadCenterAddr==(inHW*inHW-1)*iDepth)//右下角
            begin
                if(countConvCycles=='d2||countConvCycles=='d5||countConvCycles=='d6||countConvCycles=='d7||countConvCycles=='d8)//2,5,6,7,8
                begin
                    zeroMask<=1;
                end
                else
                begin
                    zeroMask<=0;
                end
            end
            else if((iReadCenterAddr<(inHW-1)*iDepth)&&(iReadCenterAddr>0))//上顶边
            begin
                if(countConvCycles=='d0||countConvCycles=='d1||countConvCycles=='d2)//0,1,2
                begin
                    zeroMask<=1;
                end
                else
                begin
                    zeroMask<=0;
                end
            end
            else if((iReadCenterAddr>(inHW)*(inHW-1)*iDepth)&&(iReadCenterAddr<(inHW*inHW-1)*iDepth))//下顶边
            begin
                if(countConvCycles=='d6||countConvCycles=='d7||countConvCycles=='d8)//6,7,8
                begin
                    zeroMask<=1;
                end
                else
                begin
                    zeroMask<=0;
                end
            end
            //else if((iReadCenterAddr%(inHW*iDepth)==0)&&(iReadCenterAddr!=(inHW)*(inHW-1)*iDepth)&&(iReadCenterAddr!=0))//左顶边
            else if (((iReadCenterAddr & (inHW * iDepth - 1))) == 0 && iReadCenterAddr > 0 && iReadCenterAddr < (inHW - 1) * inHW * iDepth)
            begin
                if(countConvCycles=='d0||countConvCycles=='d3||countConvCycles=='d6)//0,3,6
                begin
                    zeroMask<=1;
                end
                else
                begin
                    zeroMask<=0;
                end
            end
            //else if(((iReadCenterAddr+iDepth)%(inHW*iDepth)==0)&&(iReadCenterAddr!=(inHW-1)*iDepth)&&(iReadCenterAddr!=(inHW*inHW-1)*iDepth))//右顶边
            else if  (((iReadCenterAddr & (inHW * iDepth - 1))) == (inHW - 1) * iDepth && iReadCenterAddr > (inHW - 1) * iDepth && iReadCenterAddr < (inHW * inHW - 1) * iDepth)
            begin
                if(countConvCycles=='d2||countConvCycles=='d5||countConvCycles=='d8)//2,5,8
                begin
                    zeroMask<=1;
                end
                else
                begin
                     zeroMask<=0;
                end
            end
            else//内部
            begin
                zeroMask<=0;
            end

            //output select
            //oFeatureData=(zeroMask||nCe)? 'b0 : featureMemory[readAddr];
            //oFeatureData=(zeroMask)? 'b0 : featureMemory[readAddr];

        end
        else //1x1
        begin
            //oFeatureData= nCe ? 'b0 : featureMemory[readAddr];
            //oFeatureData= featureMemory[readAddr];
            zeroMask<=0;
        end
    end

    

endmodule

