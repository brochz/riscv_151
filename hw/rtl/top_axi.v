`timescale 1ns/1ns
module top_axi #(
  parameter AXI_AWIDTH = 32,
  parameter AXI_DWIDTH = 32,
  parameter AXI_MAX_BURST_LEN = 256,
  parameter CPU_CLOCK_FREQ = 50_000_000
) (
  input  sys_clk,
  input  rst,

  input  FPGA_SERIAL_RX,
  output FPGA_SERIAL_TX

  `ifndef SIMULATION
  ,
  //issi sram interface
  //To issi asram
  inout  [16-1:0] sram_data_issi,
  output [19-1:0] sram_addr_issi,
  output sram_oe_n_issi, // write enter writing status; set oe to high for writing speed
  output sram_ce_n_issi, // always low
  output sram_we_n_issi, // control
  output sram_lb_n_issi, // 
  output sram_ub_n_issi // 
  `endif 
);
  wire cpu_clk;
  wire reset = rst;
  wire [31:0] csr;

  localparam DMEM_AWIDTH = 14;
  localparam DMEM_DWIDTH = 32;

  wire dma_start, dma_done, dma_idle, dma_dir;
  wire [31:0] dma_src_addr, dma_dst_addr, dma_len;

  wire xcel_start, xcel_idle, xcel_done;

  wire [31:0] ifm_ddr_addr, wt_ddr_addr, ofm_ddr_addr;
  wire [31:0] ifm_dim;
  wire [31:0] ifm_depth;

  wire [31:0] wt_depth;

  wire [31:0] ofm_dim;
  wire [31:0] ofm_depth;

  wire [DMEM_AWIDTH-1:0] dmem_addrb;
  wire [DMEM_DWIDTH-1:0] dmem_dinb, dmem_doutb;
  wire [3:0]  dmem_web;
  wire dmem_enb;

`ifdef SIMULATION
  localparam  RESET_PC = 32'h1000_0000;
  assign cpu_clk = sys_clk;
`else
  localparam  RESET_PC =  32'h4000_0000;
  //Xilinx MMCM IP
  mmcm100_50 mmcm
  (
      // Clock out ports
      .clk_out1(cpu_clk),     // output clk_out1
    // Clock in ports
      .clk_in1(sys_clk)
  );      // input clk_in1
`endif 

  Riscv151 #(
    .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ),
    .RESET_PC(RESET_PC)
  ) CPU (
    .clk(cpu_clk),
    .rst(reset),
    .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
    .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
    .csr(csr),

    // Acccelerator Interfacing
    .xcel_start(xcel_start),
    .xcel_idle(xcel_idle & (~xcel_start)),
    .xcel_done(xcel_done & (~xcel_start)),

    .ifm_ddr_addr(ifm_ddr_addr),
    .wt_ddr_addr(wt_ddr_addr),
    .ofm_ddr_addr(ofm_ddr_addr),

    .ifm_dim(ifm_dim),
    .ifm_depth(ifm_depth),

    .ofm_dim(ofm_dim),
    .ofm_depth(ofm_depth),

    // DMA Interfacing
    .dma_start(dma_start),
    .dma_done(dma_done & (~dma_start)),
    .dma_idle(dma_idle & (~dma_start)),
    .dma_dir(dma_dir),
    .dma_src_addr(dma_src_addr),
    .dma_dst_addr(dma_dst_addr),
    .dma_len(dma_len),

    // Riscv151 DMem Interfacing
    .dmem_addrb(dmem_addrb),
    .dmem_dinb(dmem_dinb),
    .dmem_doutb(dmem_doutb),
    .dmem_web(dmem_web),
    .dmem_enb(dmem_enb)
  );


  wire                  core_read_request_valid;
  wire                  core_read_request_ready;
  wire [AXI_AWIDTH-1:0] core_read_addr;
  wire [31:0]           core_read_len;
  wire [2:0]            core_read_size;
  wire [1:0]            core_read_burst;
  wire [AXI_DWIDTH-1:0] core_read_data;
  wire                  core_read_data_valid;
  wire                  core_read_data_ready;

  wire                  core_write_request_valid;
  wire                  core_write_request_ready;
  wire [AXI_AWIDTH-1:0] core_write_addr;
  wire [31:0]           core_write_len;
  wire [2:0]            core_write_size;
  wire [1:0]            core_write_burst;
  wire [AXI_DWIDTH-1:0] core_write_data;
  wire                  core_write_data_valid;
  wire                  core_write_data_ready;

wire sram_en ;
wire [15:0] sram_q;
wire [15:0] sram_d;
wire [1:0]  sram_wbe;
wire [18:0] sram_addr;

axi2sram 
#(
  .AXI_AWIDTH  (AXI_AWIDTH  ),
  .AXI_DWIDTH  (AXI_DWIDTH  ),
  .SRAM_AWIDTH (19          ),
  .SRAM_DWIDTH (16          )
)
u_axi2sram(
  .clk                          (cpu_clk                          ),
  .rst                          (reset                            ),

  .axi2sram_read_request_valid  (core_read_request_valid  ),
  .axi2sram_read_request_ready  (core_read_request_ready  ),
  .axi2sram_read_addr           (core_read_addr           ),
  .axi2sram_read_len            (core_read_len            ),
  .axi2sram_read_size           (core_read_size           ),
  .axi2sram_read_burst          (core_read_burst          ),
  .axi2sram_read_data           (core_read_data           ),
  .axi2sram_read_data_valid     (core_read_data_valid     ),
  .axi2sram_read_data_ready     (core_read_data_ready     ),

  .axi2sram_write_request_valid (core_write_request_valid ),
  .axi2sram_write_request_ready (core_write_request_ready ),
  .axi2sram_write_addr          (core_write_addr          ),
  .axi2sram_write_len           (core_write_len           ),
  .axi2sram_write_size          (core_write_size          ),
  .axi2sram_write_burst         (core_write_burst         ),
  .axi2sram_write_data          (core_write_data          ),
  .axi2sram_write_data_valid    (core_write_data_valid    ),
  .axi2sram_write_data_ready    (core_write_data_ready    ),

  .sram_q                       (sram_q                       ),
  .sram_en                      (sram_en                      ),
  .sram_d                       (sram_d                       ),
  .sram_addr                    (sram_addr                    ),
  .sram_wbe                     (sram_wbe                     )
);

`ifdef SIMULATION
  ASYNC_RAM 
  #(
    .DWIDTH  (16  ),
    .AWIDTH  (19  ),
    .MIF_HEX ("weight16.mif")
  )
  u_SYNC_RAM(
    .clk  (cpu_clk  ),
    .addr (sram_addr ),
    .we   (|sram_wbe   ),
    .d    (sram_d    ),
    .q    (sram_q    )
  );

`else
  sram_issi_if 
    sram(
      .d         (sram_d    ),
      .addr      (sram_addr ),
      .wbe       (sram_wbe  ),
      .en        (sram_en   ),
      .clk       (cpu_clk   ),
      .q         (sram_q    ),

      .sram_dio  (sram_data_issi  ),
      .sram_addr (sram_addr_issi ),
      .sram_oe_n (sram_oe_n_issi ),
      .sram_ce_n (sram_ce_n_issi ),
      .sram_we_n (sram_we_n_issi ),
      .sram_lb_n (sram_lb_n_issi ),
      .sram_ub_n (sram_ub_n_issi )
    );
`endif 

  



  wire                  dma_read_request_valid;
  wire                  dma_read_request_ready;
  wire [AXI_AWIDTH-1:0] dma_read_addr;
  wire [31:0]           dma_read_len;
  wire [2:0]            dma_read_size;
  wire [1:0]            dma_read_burst;
  wire [AXI_DWIDTH-1:0] dma_read_data;
  wire                  dma_read_data_valid;
  wire                  dma_read_data_ready;

  wire                  dma_write_request_valid;
  wire                  dma_write_request_ready;
  wire [AXI_AWIDTH-1:0] dma_write_addr;
  wire [31:0]           dma_write_len;
  wire [2:0]            dma_write_size;
  wire [1:0]            dma_write_burst;
  wire [AXI_DWIDTH-1:0] dma_write_data;
  wire                  dma_write_data_valid;
  wire                  dma_write_data_ready;

  dma_controller #(
    .AXI_AWIDTH(AXI_AWIDTH),
    .AXI_DWIDTH(AXI_DWIDTH),
    .DMEM_AWIDTH(DMEM_AWIDTH),
    .DMEM_DWIDTH(DMEM_DWIDTH)
  ) dma_unit (
    .clk(cpu_clk),
    .resetn(~reset),

    .dma_read_request_valid(dma_read_request_valid),
    .dma_read_request_ready(dma_read_request_ready),
    .dma_read_addr(dma_read_addr),
    .dma_read_len(dma_read_len),
    .dma_read_size(dma_read_size),
    .dma_read_burst(dma_read_burst),
    .dma_read_data(dma_read_data),
    .dma_read_data_valid(dma_read_data_valid),
    .dma_read_data_ready(dma_read_data_ready),

    .dma_write_request_valid(dma_write_request_valid),
    .dma_write_request_ready(dma_write_request_ready),
    .dma_write_addr(dma_write_addr),
    .dma_write_len(dma_write_len),
    .dma_write_size(dma_write_size),
    .dma_write_burst(dma_write_burst),
    .dma_write_data(dma_write_data),
    .dma_write_data_valid(dma_write_data_valid),
    .dma_write_data_ready(dma_write_data_ready),

    .dma_start(dma_start),
    .dma_done(dma_done),
    .dma_idle(dma_idle),
    .dma_dir(dma_dir),
    .dma_src_addr(dma_src_addr),
    .dma_dst_addr(dma_dst_addr),
    .dma_len(dma_len),

    .dmem_addr(dmem_addrb),
    .dmem_din(dmem_dinb),
    .dmem_dout(dmem_doutb),
    .dmem_wbe(dmem_web),
    .dmem_en(dmem_enb)
  );

  wire                  xcel_read_request_valid;
  wire                  xcel_read_request_ready;
  wire [AXI_AWIDTH-1:0] xcel_read_addr;
  wire [31:0]           xcel_read_len;
  wire [2:0]            xcel_read_size;
  wire [1:0]            xcel_read_burst;
  wire [AXI_DWIDTH-1:0] xcel_read_data;
  wire                  xcel_read_data_valid;
  wire                  xcel_read_data_ready;

  wire                  xcel_write_request_valid;
  wire                  xcel_write_request_ready;
  wire [AXI_AWIDTH-1:0] xcel_write_addr;
  wire [31:0]           xcel_write_len;
  wire [2:0]            xcel_write_size;
  wire [1:0]            xcel_write_burst;
  wire [AXI_DWIDTH-1:0] xcel_write_data;
  wire                  xcel_write_data_valid;
  wire                  xcel_write_data_ready;

  xcel_naive #(
    .AXI_AWIDTH(AXI_AWIDTH),
    .AXI_DWIDTH(AXI_DWIDTH)
  ) xcel_unit (
    .clk(cpu_clk),
    .rst(reset),

    .xcel_read_request_valid(xcel_read_request_valid),
    .xcel_read_request_ready(xcel_read_request_ready),
    .xcel_read_addr(xcel_read_addr),
    .xcel_read_len(xcel_read_len),
    .xcel_read_size(xcel_read_size),
    .xcel_read_burst(xcel_read_burst),
    .xcel_read_data(xcel_read_data),
    .xcel_read_data_valid(xcel_read_data_valid),
    .xcel_read_data_ready(xcel_read_data_ready),

    .xcel_write_request_valid(xcel_write_request_valid),
    .xcel_write_request_ready(xcel_write_request_ready),
    .xcel_write_addr(xcel_write_addr),
    .xcel_write_len(xcel_write_len),
    .xcel_write_size(xcel_write_size),
    .xcel_write_burst(xcel_write_burst),
    .xcel_write_data(xcel_write_data),
    .xcel_write_data_valid(xcel_write_data_valid),
    .xcel_write_data_ready(xcel_write_data_ready),

    .xcel_start(xcel_start),
    .xcel_done(xcel_done),
    .xcel_idle(xcel_idle),

    .ifm_ddr_addr(ifm_ddr_addr),
    .wt_ddr_addr(wt_ddr_addr),
    .ofm_ddr_addr(ofm_ddr_addr),

    .ifm_dim(ifm_dim),
    .ifm_depth(ifm_depth),

    .ofm_dim(ofm_dim),
    .ofm_depth(ofm_depth)
  );

  wire xcel_busy;

  // High when the accelerator is running
  // Low when the accelerator is done (but yet to be restarted)
  REGISTER_R_CE #(.N(1)) acc_busy_reg (
    .clk(cpu_clk),
    .rst((xcel_done & ~xcel_start) | reset),
    .d(1'b1),
    .q(xcel_busy),
    .ce(xcel_start)
  );

  // Arbiter logic between {DMA, Accelerator} and {AXI Adapter} <-> DDR
  arbiter #(
    .AXI_AWIDTH(AXI_AWIDTH),
    .AXI_DWIDTH(AXI_DWIDTH)
  ) arb (

    .xcel_busy(xcel_busy),

     // Core interfacing (with the AXI Adapter)
    .core_read_request_valid(core_read_request_valid),   // output
    .core_read_request_ready(core_read_request_ready),   // input
    .core_read_addr(core_read_addr),                     // output
    .core_read_len(core_read_len),                       // output
    .core_read_size(core_read_size),                     // output
    .core_read_burst(core_read_burst),                   // output
    .core_read_data(core_read_data),                     // input
    .core_read_data_valid(core_read_data_valid),         // input
    .core_read_data_ready(core_read_data_ready),         // output

    .core_write_request_valid(core_write_request_valid), // output
    .core_write_request_ready(core_write_request_ready), // input
    .core_write_addr(core_write_addr),                   // output
    .core_write_len(core_write_len),                     // output
    .core_write_size(core_write_size),                   // output
    .core_write_burst(core_write_burst),                 // output
    .core_write_data(core_write_data),                   // output
    .core_write_data_valid(core_write_data_valid),       // output
    .core_write_data_ready(core_write_data_ready),       // input

    // DMA Controller interfacing
    .dma_read_request_valid(dma_read_request_valid),
    .dma_read_request_ready(dma_read_request_ready),
    .dma_read_addr(dma_read_addr),
    .dma_read_len(dma_read_len),
    .dma_read_size(dma_read_size),
    .dma_read_burst(dma_read_burst),
    .dma_read_data(dma_read_data),
    .dma_read_data_valid(dma_read_data_valid),
    .dma_read_data_ready(dma_read_data_ready),

    .dma_write_request_valid(dma_write_request_valid),
    .dma_write_request_ready(dma_write_request_ready),
    .dma_write_addr(dma_write_addr),
    .dma_write_len(dma_write_len),
    .dma_write_size(dma_write_size),
    .dma_write_burst(dma_write_burst),
    .dma_write_data(dma_write_data),
    .dma_write_data_valid(dma_write_data_valid),
    .dma_write_data_ready(dma_write_data_ready),

    // Accelerator interfacing
    .xcel_read_request_valid(xcel_read_request_valid),
    .xcel_read_request_ready(xcel_read_request_ready),
    .xcel_read_addr(xcel_read_addr),
    .xcel_read_len(xcel_read_len),
    .xcel_read_size(xcel_read_size),
    .xcel_read_burst(xcel_read_burst),
    .xcel_read_data(xcel_read_data),
    .xcel_read_data_valid(xcel_read_data_valid),
    .xcel_read_data_ready(xcel_read_data_ready),

    .xcel_write_request_valid(xcel_write_request_valid),
    .xcel_write_request_ready(xcel_write_request_ready),
    .xcel_write_addr(xcel_write_addr),
    .xcel_write_len(xcel_write_len),
    .xcel_write_size(xcel_write_size),
    .xcel_write_burst(xcel_write_burst),
    .xcel_write_data(xcel_write_data),
    .xcel_write_data_valid(xcel_write_data_valid),
    .xcel_write_data_ready(xcel_write_data_ready)
  );

endmodule
