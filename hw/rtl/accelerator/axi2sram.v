//AXI address width is 32 bit
//AXI data width is 32 bit
//SRAM address width is 19 bit 17bit valid
//SRAM data width  is 16 bit
//SRAM only support 16bit align R/W
`include "axi_consts.vh"

module axi2sram (
  clk                          ,
  rst                          ,
  axi2sram_read_request_valid  ,
  axi2sram_read_request_ready  ,
  axi2sram_read_addr           ,
  axi2sram_read_len            ,
  axi2sram_read_size           ,
  axi2sram_read_burst          ,
  axi2sram_read_data           ,
  axi2sram_read_data_valid     ,
  axi2sram_read_data_ready     ,
  axi2sram_write_request_valid ,
  axi2sram_write_request_ready ,
  axi2sram_write_addr          ,
  axi2sram_write_len           ,
  axi2sram_write_size          ,
  axi2sram_write_burst         ,
  axi2sram_write_data          ,
  axi2sram_write_data_valid    ,
  axi2sram_write_data_ready    ,
  sram_q                       ,
  sram_en                      ,
  sram_d                       ,
  sram_addr                    ,
  sram_wbe                     ,
  size_error                   ,
  burst_error                  ,
  conflict_error               
);
  parameter AXI_AWIDTH = 32;
  parameter AXI_DWIDTH = 32;

  parameter SRAM_AWIDTH = 19;
  parameter SRAM_DWIDTH = 16;

  input clk;  //max clk period = 20 ns
  input rst;
  //AXI salve interface 
  input                   axi2sram_read_request_valid;
  output                  axi2sram_read_request_ready;
  input [AXI_AWIDTH-1:0]  axi2sram_read_addr;
  input [31:0]            axi2sram_read_len;            //!只支持32bit对齐读写喽
  input [2:0]             axi2sram_read_size;           //Assume size = 32bit, no need this signal 
  input [1:0]             axi2sram_read_burst;          //Only accept INCR burst type, no need this signal

  output [AXI_DWIDTH-1:0] axi2sram_read_data;         //ok
  output                  axi2sram_read_data_valid;   //ok
  input                   axi2sram_read_data_ready;


  input                   axi2sram_write_request_valid;
  output                  axi2sram_write_request_ready;
  input [AXI_AWIDTH-1:0]  axi2sram_write_addr;
  input [31:0]            axi2sram_write_len;
  input [2:0]             axi2sram_write_size;          //Assume size = 32bit, no need this signal
  input [1:0]             axi2sram_write_burst;         //Only accept INCR burst type, no need this signal

  input [AXI_DWIDTH-1:0]  axi2sram_write_data;
  input                   axi2sram_write_data_valid;
  output                  axi2sram_write_data_ready;


  //SRAM Interface  
  input [SRAM_DWIDTH-1:0]    sram_q;      //ok

  output sram_en;
  output [SRAM_DWIDTH-1:0]   sram_d;    // Data input  ok
  output [SRAM_AWIDTH-1:0]   sram_addr; // Address input ok
  output [SRAM_DWIDTH/8-1:0] sram_wbe;  // write-byte-enable Only can write or read 16 bit at once ok

  //Debug 
  output size_error;     //if size  != 32, pull up this signal for a moment
  output burst_error;    //if burst != `BURST_INCR, pull up this signal for a moment
  output conflict_error; //if R&W request arrive at same time, pull up this signal for a moment
  //              End of port declaration
  //=====================================================

  //=====================================================
  //             FSM
  //=====================================================
  localparam IDLE  =  2'b00;
  localparam WRITE =  2'b01;
  localparam READ  =  2'b10;


  reg  [1:0]  status_reg;
  reg  [1:0]  status_next;
  wire        read_request;  //refer to axi read  request, 
  wire        write_request; //refer to axi write request, 

  wire        read_done;      //read_done = ???
  wire        write_done;     //write_done = ???

  always @(posedge clk) begin
    if (rst) 
      status_reg <= IDLE;
    else
      status_reg <= status_next;
  end

 always @(*) begin
  status_next = status_reg; //  
  case (status_reg)
    IDLE: begin
      if (read_request) status_next = READ;
      if (write_request) status_next = WRITE;
    end
    WRITE: begin
      if (write_done) status_next = IDLE;
    end
    READ: begin
      if (read_done)  status_next = IDLE;
    end
  endcase
 end

  //=====================================================
  //             sram_en
  //=====================================================
  //Always enable sram, beacause i didn't test whether the en bit works.
  assign sram_en = 1; //@port_signal@
  

  //=====================================================
  // Part of registers & counter
  //=====================================================
  //registers to stage the len and addr for both write and read request.
  //If two requests arrive at same time? Error 
  reg [31:0]            read_len_reg ;           // len  
  wire                  read_len_reg_en;
  reg [AXI_AWIDTH-1:0]  read_addr_reg;  
  wire                  read_addr_reg_en;

  reg [31:0]            write_len_reg ;           // len  
  wire                  write_len_reg_en;
  reg [AXI_AWIDTH-1:0]  write_addr_reg;  
  wire                  write_addr_reg_en;

  always @(posedge clk) begin
    if (write_addr_reg_en) write_addr_reg <= axi2sram_write_addr;
    if (write_len_reg_en)  write_len_reg  <= axi2sram_write_len + 1;
  end

  always @(posedge clk) begin
    if (read_addr_reg_en) read_addr_reg <= axi2sram_read_addr;
    if (read_len_reg_en)  read_len_reg  <= axi2sram_read_len + 1;
  end

  //count transfer length, two cycle for one transfer 
  //len_counter unit is 16 bits
  reg [31+1:0]              len_counter;   
  wire                      len_counter_en;
  wire                      len_counter_rst;
  always @(posedge clk) begin
    if(len_counter_rst) len_counter = 0;
    else 
    if(len_counter_en) len_counter = len_counter + 1;
  end
  
  //=====================================================
  // Read request
  //=====================================================
  wire read_request_fire;
  assign axi2sram_read_request_ready = status_reg == IDLE;      //@port_signal@
  assign read_request = axi2sram_read_request_valid;            //For state machine

  assign read_request_fire = read_request & status_reg == IDLE; //For register
  assign read_len_reg_en = read_request_fire;
  assign read_addr_reg_en = read_request_fire;

  //=====================================================
  // Write request
  //=====================================================
  wire write_request_fire;
  assign axi2sram_write_request_ready = status_reg == IDLE;       //@port_signal@
  assign write_request = axi2sram_write_request_valid;             //For state machine

  assign write_request_fire = write_request & status_reg == IDLE; //For registers
  assign write_len_reg_en = write_request_fire;
  assign write_addr_reg_en = write_request_fire;
  
  //=====================================================
  // At the beginning of the transfer, clear the counter
  //=====================================================
  assign len_counter_rst = read_request_fire | write_request_fire;

  //=====================================================
  // Read data from sram and put the data to axi bus.
  // We need two cycles for len + 1, and stage 16bit data.
  // Put the first 16 bit in lower position of 32bit word.
  //=====================================================
  //stage lower half word
  reg [15:0]  lower_half_word_read;
  wire        lower_half_word_read_en;
  always @(posedge clk) begin
    if(lower_half_word_read_en) lower_half_word_read = sram_q;
  end
  
  //To SRAM Addr
  wire  [SRAM_AWIDTH-1:0]   sram_read_addr;
  wire read_data_fire;
  assign sram_read_addr = len_counter + {read_addr_reg[31:2],1'b0}; //dont care last two byte 
  assign lower_half_word_read_en = (len_counter[0] == 1'b0) && (status_reg == READ);
  //put data to axi bus 
  //!读出去的32bit只取决于request 地址的[31:2], 写sram同理
  assign axi2sram_read_data = {sram_q, lower_half_word_read};
  assign axi2sram_read_data_valid = (status_reg == READ) && (len_counter[0] == 1'b1);
  assign read_data_fire = axi2sram_read_data_valid & axi2sram_read_data_ready;

  
  //=====================================================
  // Write data to sram
  //=====================================================
  //stage half word
  reg [15:0] higher_half_word_write;
  wire higher_half_word_write_en;
  always @(posedge clk) begin
    if(higher_half_word_write_en) higher_half_word_write = axi2sram_write_data[31:16];
  end

  //To SRAM Addr
  wire  [SRAM_AWIDTH-1:0]   sram_write_addr;
  wire  write_data_fire;
  wire  sram_write_en;
  assign sram_write_addr = len_counter + {write_addr_reg[31:2], 1'b0};
  assign axi2sram_write_data_ready = (status_reg==WRITE) && (len_counter[0]==1'b0);
  assign write_data_fire = axi2sram_write_data_ready & axi2sram_write_data_valid;
  assign higher_half_word_write_en = write_data_fire;
 

  assign sram_d = len_counter[0] == 1'b0 ? axi2sram_write_data[15:0] : higher_half_word_write;
  assign sram_write_en = write_data_fire || ((status_reg==WRITE) && (len_counter[0]==1'b1));
  assign sram_wbe = {2{sram_write_en}};

  //=====================================================
  // Counter en
  //=====================================================
  assign len_counter_en = ((read_data_fire||len_counter[0]==1'b0) & status_reg==READ) ||
                          ((write_data_fire||len_counter[0]==1'b1) & status_reg==WRITE);

  assign write_done = (len_counter == {write_len_reg, 1'b0} - 1) && len_counter_en;
  assign read_done =  (len_counter == {read_len_reg, 1'b0} - 1)  && len_counter_en;

  //=====================================================
  // SRAM addr
  //=====================================================
  assign sram_addr = status_reg==READ ? sram_read_addr: sram_write_addr;

  //=====================================================
  // Error signal
  //=====================================================
  assign size_error = read_request_fire & (axi2sram_read_size != 3'd2) ||
                      write_request_fire & (axi2sram_write_size != 3'd2);

  assign burst_error = read_request_fire & (axi2sram_read_burst != `BURST_INCR) ||
                       write_request_fire & (axi2sram_write_burst != `BURST_INCR);

  assign conflict_error = read_request_fire & write_request_fire;
endmodule