`include "Opcode.vh"
`include "IOmap.vh"

module Riscv151 #(
  parameter CPU_CLOCK_FREQ = 100_000_000,
  parameter RESET_PC       = 32'h4000_0000,
  parameter BAUD_RATE      = 115200,
  parameter BIOS_MIF_HEX   = "bios151v3.mif"
) (
  input  clk,
  input  rst,    //connect to ego1 s0
  input  FPGA_SERIAL_RX,
  output FPGA_SERIAL_TX,
  output [31:0] csr,
  // Accelerator Interfacing
  output xcel_start,
  input xcel_done,
  input xcel_idle,
  output [31:0] ifm_ddr_addr, 
  output [31:0] wt_ddr_addr,  
  output [31:0] ofm_ddr_addr, 
  output [31:0] ifm_dim,      
  output [31:0] ifm_depth,    
  output [31:0] ofm_dim,      
  output [31:0] ofm_depth,    
  // DMA Interfacing
  output dma_start,
  input dma_done,
  input dma_idle,
  output dma_dir,
  output [31:0] dma_src_addr,
  output [31:0] dma_dst_addr,
  output [31:0] dma_len,

  // DMem Interfacing (Port b)
  input [13:0] dmem_addrb,
  input [31:0] dmem_dinb,
  output [31:0] dmem_doutb,
  input [3:0] dmem_web,
  input dmem_enb
);
  // Memories
  localparam BIOS_AWIDTH = 12; //4KB BIOS
  localparam BIOS_DWIDTH = 32;

  wire [BIOS_AWIDTH-1:0] bios_addra, bios_addrb;
  wire [BIOS_DWIDTH-1:0] bios_douta, bios_doutb;

  // BIOS Memory
  // Synchronous read: read takes one cycle
  // Synchronous write: write takes one cycle
  SYNC_ROM_DP #(
    .AWIDTH(BIOS_AWIDTH),
    .DWIDTH(BIOS_DWIDTH),
    .MIF_HEX(BIOS_MIF_HEX)
  ) bios_mem(
    .q0(bios_douta),    // instruction output 
    .addr0(bios_addra), // input
    .en0(1'b1),

    .q1(bios_doutb),    // data output
    .addr1(bios_addrb), // input
    .en1(1'b1),

    .clk(clk)
  );

  localparam DMEM_AWIDTH = 14;
  localparam DMEM_DWIDTH = 32;

  wire [DMEM_AWIDTH-1:0] dmem_addra;
  wire [DMEM_DWIDTH-1:0] dmem_dina, dmem_douta;
  wire [3:0] dmem_wea;

  // Data Memory
  // Synchronous read: read takes one cycle
  // Synchronous write: write takes one cycle
  // Write-byte-enable: select which of the four bytes to write
  // SYNC_RAM_WBE #(
  //   .AWIDTH(DMEM_AWIDTH),
  //   .DWIDTH(DMEM_DWIDTH)
  // ) dmem (
  //   .q(dmem_douta),    // output
  //   .d(dmem_dina),     // input
  //   .addr(dmem_addra), // input
  //   .wbe(dmem_wea),    // input
  //   .en(1'b1),
  //   .clk(clk)
  // );
  SYNC_RAM_DP_WBE 
  #(
    .DWIDTH  (DMEM_DWIDTH),
    .AWIDTH  (DMEM_AWIDTH)
  ) dmem(
    .clk   (clk          ),

    .d0    (dmem_dina    ),
    .addr0 (dmem_addra   ),
    .wbe0  (dmem_wea     ),
    .en0   (1'b1         ),
    .q0    (dmem_douta   ),

    .d1    (dmem_dinb    ),
    .addr1 (dmem_addrb   ),
    .wbe1  (dmem_web     ),
    .en1   (dmem_enb     ),
    .q1    (dmem_doutb   )
  );


  localparam IMEM_AWIDTH = 14;
  localparam IMEM_DWIDTH = 32;

  wire [IMEM_AWIDTH-1:0] imem_addra, imem_addrb;
  wire [IMEM_DWIDTH-1:0] imem_douta, imem_doutb;
  wire [IMEM_DWIDTH-1:0] imem_dina, imem_dinb;
  wire [3:0] imem_wea, imem_web;
  //Hardwire imem_dina to 0, this port is read only!
  assign imem_dina = 0;

  // Instruction Memory
  // Synchronous read: read takes one cycle
  // Synchronous write: write takes one cycle
  // Write-byte-enable: select which of the four bytes to write
  // 
  SYNC_RAM_DP_WBE #(
    .AWIDTH(IMEM_AWIDTH),
    .DWIDTH(IMEM_DWIDTH)
  ) imem (
    //instrction read port
    .q0(imem_douta),    // output
    .d0(imem_dina),     // input
    .addr0(imem_addra), // input
    .wbe0(imem_wea),    // input
    .en0(1'b1),

    //data write port
    .q1(imem_doutb),    // output
    .d1(imem_dinb),     // input
    .addr1(imem_addrb), // input
    .wbe1(imem_web),    // input
    .en1(1'b1),

    .clk(clk)
  );

  wire rf_we;
  wire [4:0]  rf_ra1, rf_ra2, rf_wa;
  wire [31:0] rf_wd;
  wire [31:0] rf_rd1, rf_rd2;

  // Asynchronous read: read data is available in the same cycle
  // Synchronous write: write takes one cycle
  // register file
  ASYNC_RAM_1W2R # (
    .AWIDTH(5),
    .DWIDTH(32)
  ) rf (
    .d0(rf_wd),     // input
    .addr0(rf_wa),  // input
    .we0(rf_we),    // input

    .q1(rf_rd1),    // output
    .addr1(rf_ra1), // input

    .q2(rf_rd2),    // output
    .addr2(rf_ra2), // input

    .clk(clk)
  );

  // UART Receiver
  wire [7:0] uart_rx_data_out;
  wire uart_rx_data_out_valid;
  wire uart_rx_data_out_ready;

  uart_receiver #(
    .CLOCK_FREQ(CPU_CLOCK_FREQ),
    .BAUD_RATE(BAUD_RATE)
  ) uart_rx (
    .clk(clk),
    .rst(rst),
    .data_out(uart_rx_data_out),             // output
    .data_out_valid(uart_rx_data_out_valid), // output
    .data_out_ready(uart_rx_data_out_ready), // input
    .serial_in(FPGA_SERIAL_RX)               // input
  );

  // UART Transmitter
  wire [7:0] uart_tx_data_in;
  wire uart_tx_data_in_valid;
  wire uart_tx_data_in_ready;

  uart_transmitter #(
    .CLOCK_FREQ(CPU_CLOCK_FREQ),
    .BAUD_RATE(BAUD_RATE)
  ) uart_tx (
    .clk(clk),
    .rst(rst),
    .data_in(uart_tx_data_in),             // input
    .data_in_valid(uart_tx_data_in_valid), // input
    .data_in_ready(uart_tx_data_in_ready), // output
    .serial_out(FPGA_SERIAL_TX)            // output
  );

  //cycle counter  & Instruction counter 
  reg [31:0] cycle_counter;
  reg [31:0] instrction_counter;  //#Instruction have been fetched
  wire cycle_counter_clr;
  wire instrction_counter_clr;
  wire flush;
  always @(posedge clk) begin
    if (rst | cycle_counter_clr)
      cycle_counter <= 0;
    else
      cycle_counter <= cycle_counter + 1;
  end

  always @(posedge clk) begin
    if(rst | instrction_counter_clr)
      instrction_counter <= 0;
    else if (~flush)
      instrction_counter <= instrction_counter + 1; 
  end

  
  //=================================================
  //               DMA Control Registers 
  //=================================================
  //dir reg
  reg dma_direct_r;  //No need rst
  wire dma_direct_r_en;
  wire dma_direct_r_d;
  always @(posedge clk) begin
    if(dma_direct_r_en)
      dma_direct_r <= dma_direct_r_d; 
  end
  assign dma_dir = dma_direct_r;
  //src & des addr
  reg [31:0]  dma_srcaddr_r, dma_desaddr_r;
  wire[31:0] dma_srcaddr_r_d, dma_desaddr_r_d;
  wire dma_srcaddr_r_en, dma_desaddr_r_en;
  always @(posedge clk) begin
    if(dma_srcaddr_r_en)
      dma_srcaddr_r <= dma_srcaddr_r_d; 
  end

  always @(posedge clk) begin
    if(dma_desaddr_r_en)
      dma_desaddr_r <= dma_desaddr_r_d; 
  end
  assign dma_dst_addr = dma_desaddr_r;
  assign dma_src_addr = dma_srcaddr_r;
  //dma transfer length 
  reg [31:0] dma_len_r;
  wire [31:0] dma_len_r_d;
  wire dma_len_r_en;

  always @(posedge clk) begin
    if(dma_len_r_en)
      dma_len_r <= dma_len_r_d; 
  end
  assign dma_len = dma_len_r;

  //=================================================
  //               Xcel Control Registers 
  //=================================================
  reg [31:0] xcel_ifmaddr_r;
  reg [31:0] xcel_weiaddr_r;
  reg [31:0] xcel_ofmaddr_r;
  reg [31:0] xcel_ifmdims_r;
  reg [31:0] xcel_ifmdpth_r;
  reg [31:0] xcel_ofmdims_r;
  reg [31:0] xcel_ofmdpth_r;

  wire [31:0] xcel_ifmaddr_r_d;
  wire [31:0] xcel_weiaddr_r_d;
  wire [31:0] xcel_ofmaddr_r_d;
  wire [31:0] xcel_ifmdims_r_d;
  wire [31:0] xcel_ifmdpth_r_d;
  wire [31:0] xcel_ofmdims_r_d;
  wire [31:0] xcel_ofmdpth_r_d;

  wire xcel_ifmaddr_r_en   ;
  wire xcel_weiaddr_r_en   ;
  wire xcel_ofmaddr_r_en   ;
  wire xcel_ifmdims_r_en   ;
  wire xcel_ifmdpth_r_en   ;
  wire xcel_ofmdims_r_en   ;
  wire xcel_ofmdpth_r_en   ;  
  
  always @(posedge clk) begin
    if(xcel_ifmaddr_r_en) xcel_ifmaddr_r <= xcel_ifmaddr_r_d;
    if(xcel_weiaddr_r_en) xcel_weiaddr_r <= xcel_weiaddr_r_d;
    if(xcel_ofmaddr_r_en) xcel_ofmaddr_r <= xcel_ofmaddr_r_d;
    if(xcel_ifmdims_r_en) xcel_ifmdims_r <= xcel_ifmdims_r_d;
    if(xcel_ifmdpth_r_en) xcel_ifmdpth_r <= xcel_ifmdpth_r_d;
    if(xcel_ofmdims_r_en) xcel_ofmdims_r <= xcel_ofmdims_r_d;
    if(xcel_ofmdpth_r_en) xcel_ofmdpth_r <= xcel_ofmdpth_r_d;    
  end

  assign ifm_ddr_addr    = xcel_ifmaddr_r;
  assign wt_ddr_addr     = xcel_weiaddr_r;
  assign ofm_ddr_addr    = xcel_ofmaddr_r;
  assign ifm_dim         = xcel_ifmdims_r;
  assign ifm_depth       = xcel_ifmdpth_r;    
  assign ofm_dim         = xcel_ofmdims_r;
  assign ofm_depth       = xcel_ofmdpth_r; 



  //=================================================
  //               Part of Signal
  //=================================================

  wire [31:0] brach_addr;
  wire PC_src;   //PC_src, set for branch


  //=================================================
  //               IF Stage
  //=================================================
  //PC logic
  reg [31:0] PC;
  always @(posedge clk ) begin
    if(rst) begin
      PC <= RESET_PC;
    end else begin
      PC <= PC_src ? brach_addr : PC + 4;
    end
  end
  
  //Fetch instruction
  wire [31:0] instruction_IF;
  reg  [31:0] PC_IF;  // register last PC value, for next stage use 

  //BIOS instruction fetch, 
  //Because the mem is word address, we abandon the last two bits of PC
  assign bios_addra = PC[BIOS_AWIDTH+2-1 : 2];
  //imem instruction fetch
  assign imem_addra = PC[IMEM_AWIDTH+2-1 : 2];
  assign imem_wea = 0;  //Never write this port

  //register last PC, no reset
  always @(posedge clk ) begin
    PC_IF <= PC;
  end

  //register PC_src, if jump, then flush in next cycle
  reg PC_src_d;
  always @(posedge clk) begin
    PC_src_d <= rst? 0: PC_src; //First cycle no flush!
  end
  //mux the instrcution and gate with flush signal
  assign flush = PC_src_d;
  assign instruction_IF = (PC_IF[30] ? bios_douta : imem_douta) & {32{~flush}};



  //=================================================
  //              ID/EX/MEM
  //=================================================

  //Decode some signals
  wire [6:0] opcode = instruction_IF[6:0];
  wire [2:0] funct3 = instruction_IF[14:12];
  wire [6:0] funct7 = instruction_IF[31:25];
  wire [4:0] rs1_addr = instruction_IF[19:15];
  wire [4:0] rs2_addr = instruction_IF[24:20];
  wire [4:0] rd_addr  = instruction_IF[11:7];


  //immGen
  reg [31:0] immGen; //This is a wire signal
  //cat and sign extend the imm from instrction
  //immGen can be used for add directly
  always @(*) begin
    immGen = 0; //default value
    case (opcode)
      // I type
      `OPC_ARI_ITYPE : immGen = {{21{instruction_IF[31]}}, instruction_IF[30:20]};
      `OPC_LOAD      : immGen = {{21{instruction_IF[31]}}, instruction_IF[30:20]};
      `OPC_JALR      : immGen = {{21{instruction_IF[31]}}, instruction_IF[30:20]};
      
      //S type
      `OPC_STORE     : immGen = {{21{instruction_IF[31]}}, instruction_IF[30:25], 
                        instruction_IF[11:7]};
      //B type, immGen no need shift any more, can use directly
      `OPC_BRANCH    : immGen = {{21{instruction_IF[31]}}, instruction_IF[7], 
                        instruction_IF[30:25], instruction_IF[11:8]} << 1;
      //U type, << 12
      `OPC_LUI       : immGen = {instruction_IF[31:12], 12'b0};
      `OPC_AUIPC     : immGen = {instruction_IF[31:12], 12'b0};

      //J type  << 1
      `OPC_JAL       : immGen = {{13{instruction_IF[31]}}, instruction_IF[19:12],
                        instruction_IF[20], instruction_IF[30:21]} << 1;
    endcase
  end

  //Get rf_rd1 and rf_rd2 from register file(ASYNC)
  assign rf_ra1 = rs1_addr;
  assign rf_ra2 = rs2_addr;

  //Data hazard, rf_rd1 -> rf_rd1_forward,
  //rf_rd2 ->rf_rd2_forward
  //The logic has been put at the end of the file
  reg [31:0] rf_rd1_forward;
  reg [31:0] rf_rd2_forward;
  /*
  The code is at the bottom of the file.
  always @(*) begin
    rf_rd1_forward = rf_rd1;
    if (rdwen_WB && rd_addr_WB!=0 && rd_addr_WB==rs1_addr) begin
      rf_rd1_forward = rf_wd;
    end
  end

  always @(*) begin
    rf_rd2_forward = rf_rd2;
    if (rdwen_WB && rd_addr_WB!=0 && rd_addr_WB==rs2_addr) begin
      rf_rd2_forward = rf_wd;
    end
  end
  */



  //ALU control
  wire [31:0] alu_b, alu_res;
  wire alu_branch;

  //ALU 
  alu alu1(
    .a(rf_rd1_forward),
    .b(alu_b),
    .opcode(opcode),
    .funct3(funct3),
    .funct7(funct7),

    .branch(alu_branch),
    .alu_res(alu_res)
  );
  //alu_b = rf_rd2_forward IF alu_src == 1
  assign alu_b = opcode==`OPC_BRANCH || opcode==`OPC_ARI_RTYPE ? rf_rd2_forward : immGen; 
  
  //brach address
  //jarl need rs1 output 
  assign brach_addr = opcode==`OPC_JALR ? rf_rd1_forward+immGen :PC_IF + immGen;


  //jmp
  //set jmp if jal or jalr occurs
  wire jmp;
  assign jmp = opcode==`OPC_JALR || opcode==`OPC_JAL;

  //PC_src
  assign PC_src = jmp | alu_branch;
  

  //Reg write control
  wire  rdwen;   //rd write enable  wire
  wire  rd_src;  // set if rd data from mem?
  reg [31:0] rd_data_noload; //This is a set of wire

  //R type, I type, J type, U type
  assign  rdwen = (opcode == `OPC_ARI_RTYPE) || (opcode == `OPC_ARI_ITYPE) || 
                  (opcode == `OPC_LOAD) || (opcode == `OPC_JAL)||
                  (opcode == `OPC_JALR) || (opcode == `OPC_LUI)||
                  (opcode == `OPC_AUIPC);

  assign rd_src =  opcode == `OPC_LOAD;
  always @(*) begin
    rd_data_noload = alu_res;
    case(opcode)
      `OPC_JAL : rd_data_noload = PC_IF + 4;
      `OPC_JALR: rd_data_noload = PC_IF + 4;
      `OPC_LUI : rd_data_noload = immGen;
      `OPC_AUIPC: rd_data_noload = PC_IF + immGen;
    endcase
  end


  //Dmem Wrtie enable signal 
  reg [3:0] wbe; //DMEM write enable wire
  reg [31:0] dmem_in; //This signal connect to dmem interface 
  wire store; //Indicate whether the instruction is a store 
  assign store = opcode == `OPC_STORE;

  //store wbe logic & adjust data position for sb and sh
  //data mem in include IO ...
  always @(*) begin
    wbe = 0;
    dmem_in = rf_rd2_forward;
    case (funct3)  //default rf_rd2_forward
      3'h0 : begin
        wbe = 4'b0001 << alu_res[1:0] & {4{store}};  //sb
        //dmem_in = rf_rd2_forward << alu_res[1:0] * 8 
        dmem_in = rf_rd2_forward << {alu_res[1:0], 3'b0}; //adjust the data offset
      end
      3'h1 : begin
        wbe = 4'b0011 << alu_res[1]*2 & {4{store}};     //sh
        //dmem_in = rf_rd2_forward << alu_res[1] * 16 
        dmem_in = rf_rd2_forward << {alu_res[1], 4'b0}; //adjust the data offset 
      end
      3'h2 : wbe = 4'b1111 & {4{store}};  //sw
    endcase
  end

  //csr
  reg [31:0] csrr;
  always @(posedge clk) begin
    if (rst) 
      csrr <= 0;
    else if(opcode == 7'b1110011 && funct3 == 3'b001)
      csrr <= rf_rd1_forward;
    else if(opcode == 7'b1110011 && funct3 == 3'b101)
      csrr <= {27'b0, rs1_addr};
  end 
  assign csr = csrr;

  //addr TO DMEM & IO 
  //TODO: remember to add IO
  assign bios_addrb = alu_res[BIOS_AWIDTH-1+2:2]; //RO
  assign dmem_addra = alu_res[DMEM_AWIDTH-1+2:2]; //RW
  assign imem_addrb = alu_res[IMEM_AWIDTH-1+2:2]; //WO

  //mem sel
  wire dmem_sel;
  wire imem_sel; 
  wire bmem_sel; //bios

  //Counter write
  wire counter_rst; //happens in MEM stage
  assign counter_rst = (alu_res == `COUNTER_RST_W) & store;
  assign cycle_counter_clr = counter_rst;
  assign instrction_counter_clr = counter_rst;

  //UART write, happens in MEM stage
  assign uart_tx_data_in = dmem_in[7:0];
  assign uart_tx_data_in_valid = (alu_res == `UART_DATA_W) & store;


  //# DMA 
  //DMA write, Prevent dma_start entry unknown state in the beginning gate with rst
  assign dma_start = (alu_res == `DMA_CONTROL_W) & store & (~rst);
  //DMA direction reg
  assign dma_direct_r_en = (alu_res == `DMA_DIRECT_W) & store;
  assign dma_direct_r_d = dmem_in[0];
  //DMA src & des addr reg
  assign dma_srcaddr_r_en = (alu_res == `DMA_SRCADDR_W) & store;
  assign dma_desaddr_r_en = (alu_res == `DMA_DESADDR_W) & store;
  assign dma_srcaddr_r_d = dmem_in;
  assign dma_desaddr_r_d = dmem_in;
  //DMA len reg
  assign dma_len_r_en = (alu_res == `DMA_TLEN_W) & store;
  assign dma_len_r_d  = dmem_in;

  //# Xcel
  //Xcel start pulse 
  assign xcel_start = (alu_res == `XCEL_CONTROL_W) & store & (~rst);
  //Xcel configure register 
  assign xcel_ifmaddr_r_en = (alu_res == `XCEL_IFMADDR_W);
  assign xcel_weiaddr_r_en = (alu_res == `XCEL_WEIADDR_W);
  assign xcel_ofmaddr_r_en = (alu_res == `XCEL_OFMADDR_W);
  assign xcel_ifmdims_r_en = (alu_res == `XCEL_IFMDIMS_W);
  assign xcel_ifmdpth_r_en = (alu_res == `XCEL_IFMDPTH_W);
  assign xcel_ofmdims_r_en = (alu_res == `XCEL_OFMDIMS_W);
  assign xcel_ofmdpth_r_en = (alu_res == `XCEL_OFMDPTH_W); 

  assign xcel_ifmaddr_r_d = dmem_in;
  assign xcel_weiaddr_r_d = dmem_in;
  assign xcel_ofmaddr_r_d = dmem_in;
  assign xcel_ifmdims_r_d = dmem_in;
  assign xcel_ifmdpth_r_d = dmem_in;
  assign xcel_ofmdims_r_d = dmem_in;
  assign xcel_ofmdpth_r_d = dmem_in;
   

  //mem sel...
  assign dmem_sel = alu_res[31:28] == 4'b0001 || alu_res[31:28] == 4'b0011; 
  assign imem_sel = alu_res[31:28] == 4'b0001 || alu_res[31:28] == 4'b0011;
  assign bmem_sel = alu_res[31:28] == 4'b0100;  //

  //write enable
  assign dmem_wea = {4{dmem_sel}} & wbe;
  assign imem_web = {4{imem_sel & PC_IF[30]}} & wbe; //Only bios code can write imem

  //hook dmem in to dmem and imem
  assign dmem_dina = dmem_in;
  assign imem_dinb = dmem_in;

  //signal to next stage, next pose


  //register signal for next stage use
  reg        rdwen_WB, rd_src_WB;
  reg [31:0] instruction_WB;
  reg [31:0] rd_data_noload_WB;
  reg [31:0] alu_res_WB;
  wire [1:0]  offset_addr_WB;
  reg dmem_sel_WB;
  reg imem_sel_WB;
  reg bmem_sel_WB;

  always @(posedge clk) begin
    rdwen_WB  <=  rdwen;
    rd_src_WB <=  rd_src;
    rd_data_noload_WB <= rd_data_noload;
    instruction_WB <= instruction_IF;
    alu_res_WB <= alu_res;
    dmem_sel_WB <= dmem_sel;
    imem_sel_WB <= imem_sel;
    bmem_sel_WB <= bmem_sel;
  end

  assign  offset_addr_WB = alu_res_WB[1:0];


  //=================================================
  //              WB TO REGISTER FILE
  //=================================================
  //mem read sel
  //TODO: Remember to add the IO data 
  reg [31:0] memdout; //A latch,
  always @(*) begin
    if (instruction_WB[6:0]==`OPC_LOAD) begin
      if (dmem_sel_WB)                    memdout = dmem_douta;//data from dmem
      if (bmem_sel_WB)                    memdout = bios_doutb; //data from bios
      //data from io ...
      if (alu_res_WB == `UART_CONTROL_R)  memdout = {30'h0, uart_rx_data_out_valid, uart_tx_data_in_ready};
      if (alu_res_WB == `UART_DATA_R)     memdout = {24'h0, uart_rx_data_out}; 
      if (alu_res_WB == `COUNTER_CYCLE_R) memdout = cycle_counter; 
      if (alu_res_WB == `COUNTER_INS_R)   memdout = instrction_counter; 
      //dma status read 
      if (alu_res_WB == `DMA_STATUS_R)    memdout = {30'b0, dma_idle, dma_done}; 
      //Xcel status read 
      if (alu_res_WB == `XCEL_STATUS_R)   memdout = {30'b0, xcel_idle, xcel_done};
      //TODO: Add more io ...
    end
  end

  //read data to rf from uart
  assign uart_rx_data_out_ready = rdwen_WB && (alu_res_WB == `UART_DATA_R);


  wire  [4:0 ] rd_addr_WB;
  assign rd_addr_WB = instruction_WB[11:7];
  wire [2:0] funct3_WB;
  assign funct3_WB = instruction_WB[14:12];
  //lb, lb, lw, lbu, lhu, 
  reg [31:0] load_data;
  reg [31:0] tmp_data;
  always @(*) begin
    load_data = 0;
    tmp_data  = 0;
    case (funct3_WB) 
      3'h0 : begin //lb
        //tmp_data = memdout >> (offset_addr_WB * 8);
        tmp_data = memdout >> {offset_addr_WB, 3'b0};
        load_data = {{25{tmp_data[7]}}, tmp_data[6:0]};
      end
      3'h1 : begin //lh
        //tmp_data = memdout >> (offset_addr_WB[1] * 16);
        tmp_data = memdout >> {offset_addr_WB[1], 4'b0};
        load_data = {{17{tmp_data[15]}}, tmp_data[14:0]};
      end
      3'h2 : load_data[31:0] = memdout[31:0];  //lw
      //3'h4 : load_data[7 :0] = memdout >> (offset_addr_WB * 8);    //lbu
      3'h4 : load_data[7 :0] = memdout >> {offset_addr_WB, 3'b0};    //lbu
      //3'h5 : load_data[15:0] = memdout >> (offset_addr_WB[1] * 16); //lhu
      3'h5 : load_data[15:0] = memdout >> {offset_addr_WB[1], 4'b0}; //lhu
    endcase
  end

  assign rf_wd = rd_src_WB ? load_data : rd_data_noload_WB;
  assign rf_we = rdwen_WB;
  assign rf_wa = rd_addr_WB;

  //=================================================
  //              Global
  //=================================================

  //Data hazard logic 
  always @(*) begin
    rf_rd1_forward = rf_rd1; 
    if (rdwen_WB && rd_addr_WB!=0 && rd_addr_WB==rs1_addr) begin
      rf_rd1_forward = rf_wd;
    end
  end

  always @(*) begin
    rf_rd2_forward = rf_rd2;
    if (rdwen_WB && rd_addr_WB!=0 && rd_addr_WB==rs2_addr) begin
      rf_rd2_forward = rf_wd;
    end
  end

endmodule
