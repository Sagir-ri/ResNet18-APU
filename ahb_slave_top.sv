// `timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/04/13 09:33:37
// Design Name: 
// Module Name: ahb_slave_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
// limitations:
//  - no partial access supported; only word access
//  - no wait process
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ahb_slave_top #(
    parameter T_ADDR_WID = 14
) (
    input         hresetn,
    input         hclk,
    input         hsel,
    input  [31:0] haddr,
    input  [ 1:0] htrans,
    input         hwrite,
    input  [ 2:0] hsize,
    input  [ 2:0] hburst,
    input  [31:0] hwdata,
    output [31:0] hrdata,
    output [ 1:0] hresp,
    output        hready,

    output data_ram_ctrl,
    output conv_ram_ctrl,
    output        apu_ready,
    input      cal_cpl,
    output    int_cal,

    output        ir_ram_wen,
    output [ 3:0] ir_ram_waddr,
    output [31:0] ir_ram_wdata,
    output        ir_ram_ren,
    output [ 3:0] ir_ram_raddr,
    input  [31:0] ir_ram_rdata,

    output        in_ram_wen,
    output [ 9:0] in_ram_waddr,
    output [63:0] in_ram_wdata,
    output        in_ram_ren,
    output [ 9:0] in_ram_raddr,
    input  [63:0] in_ram_rdata,

    output        out_ram_wen,
    output [ 9:0] out_ram_waddr,
    output [63:0] out_ram_wdata,
    output        out_ram_ren,
    output [ 9:0] out_ram_raddr,
    input  [63:0] out_ram_rdata,

    output [ 5:0] conv_ram_sel,
    output        conv_ram_wen,
    output [ 7:0] conv_ram_waddr,
    output [63:0] conv_ram_wdata,
    output        conv_ram_ren,
    output [ 7:0] conv_ram_raddr,
    input  [63:0] conv_ram_rdata,

    output [ 5:0] bn_ram_sel,
    output        bn_ram_wen,
    output [ 4:0] bn_ram_waddr,
    output [12:0] bn_ram_wdata,
    output        bn_ram_ren,
    output [ 4:0] bn_ram_raddr,
    input  [12:0] bn_ram_rdata
);

  wire [T_ADDR_WID-1:0] t_waddr;
  wire [T_ADDR_WID-1:0] t_raddr;
  wire                  t_wren;
  wire                  t_rden;
  wire [          31:0] t_wdata;
  wire [          31:0] t_rdata;
  wire [          10:0] ram_raddr;
  wire [          10:0] ram_waddr;
  wire                  ram_wen;
  wire                  ram_ren;
  wire [          31:0] ram_wdata;
  wire [          31:0] ram_rdata;
  wire [           7:0] ram_sel;

  ahb_slave #(
      .T_ADDR_WID(T_ADDR_WID)
  ) ahb_slave_inst (
      .hresetn(hresetn),
      .hclk   (hclk),
      .hsel   (hsel),
      .haddr  (haddr),
      .htrans (htrans),
      .hwrite (hwrite),
      .hsize  (hsize),
      .hburst (hburst),
      .hwdata (hwdata),
      .hrdata (hrdata),
      .hresp  (hresp),
      .hready (hready),
      .t_waddr(t_waddr),
      .t_raddr(t_raddr),
      .t_wren (t_wren),
      .t_rden (t_rden),
      .t_wdata(t_wdata),
      .t_rdata(t_rdata)
  );

  addr_map #(
      .T_ADDR_WID(T_ADDR_WID)
  ) addr_map_inst (
      .clk          (hclk),
      .rstn         (hresetn),
      .t_waddr      (t_waddr),
      .t_raddr      (t_raddr),
      .t_wren       (t_wren),
      .t_rden       (t_rden),
      .t_wdata      (t_wdata),
      .t_rdata      (t_rdata),
      .ram_waddr    (ram_waddr),
      .ram_raddr    (ram_raddr),
      .ram_wen      (ram_wen),
      .ram_ren      (ram_ren),
      .ram_wdata    (ram_wdata),
      .ram_rdata    (ram_rdata),
      .ram_sel      (ram_sel),
      .data_ram_ctrl(data_ram_ctrl),
      .conv_ram_ctrl(conv_ram_ctrl),
      .apu_ready    (apu_ready),
      .cal_cpl      (cal_cpl),
      .int_cal      (int_cal)
  );

  ram_mux ram_mux_inst (
      .clk           (hclk),
      .rstn          (hresetn),
      .ram_waddr     (ram_waddr),
      .ram_raddr     (ram_raddr),
      .ram_wen       (ram_wen),
      .ram_ren       (ram_ren),
      .ram_wdata     (ram_wdata),
      .ram_rdata     (ram_rdata),
      .ram_sel       (ram_sel),
      .ir_ram_wen    (ir_ram_wen),
      .ir_ram_waddr  (ir_ram_waddr),
      .ir_ram_wdata  (ir_ram_wdata),
      .ir_ram_ren    (ir_ram_ren),
      .ir_ram_raddr  (ir_ram_raddr),
      .ir_ram_rdata  (ir_ram_rdata),
      .in_ram_wen    (in_ram_wen),
      .in_ram_waddr  (in_ram_waddr),
      .in_ram_wdata  (in_ram_wdata),
      .in_ram_ren    (in_ram_ren),
      .in_ram_raddr  (in_ram_raddr),
      .in_ram_rdata  (in_ram_rdata),
      .out_ram_wen   (out_ram_wen),
      .out_ram_waddr (out_ram_waddr),
      .out_ram_wdata (out_ram_wdata),
      .out_ram_ren   (out_ram_ren),
      .out_ram_raddr (out_ram_raddr),
      .out_ram_rdata (out_ram_rdata),
      .conv_ram_sel  (conv_ram_sel),
      .conv_ram_wen  (conv_ram_wen),
      .conv_ram_waddr(conv_ram_waddr),
      .conv_ram_wdata(conv_ram_wdata),
      .conv_ram_ren  (conv_ram_ren),
      .conv_ram_raddr(conv_ram_raddr),
      .conv_ram_rdata(conv_ram_rdata),
      .bn_ram_sel    (bn_ram_sel),
      .bn_ram_wen    (bn_ram_wen),
      .bn_ram_waddr  (bn_ram_waddr),
      .bn_ram_wdata  (bn_ram_wdata),
      .bn_ram_ren    (bn_ram_ren),
      .bn_ram_raddr  (bn_ram_raddr),
      .bn_ram_rdata  (bn_ram_rdata)
  );
endmodule
