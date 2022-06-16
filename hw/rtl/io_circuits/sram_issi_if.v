module sram_issi_if 
(
  d, addr, wbe, en, clk,q,
  sram_dio, sram_addr,
  sram_oe_n, sram_ce_n,
  sram_we_n, sram_lb_n,
  sram_ub_n
);
  parameter DWIDTH = 16; 
  parameter AWIDTH = 19; //! 只有17bit有效, 2Mbit ~ 512Kb ~256k half word sram的地址只有A0-16 17bits


//naive sync sram interface 
  input [DWIDTH-1:0]   d;    // Data input
  input [AWIDTH-1:0]   addr; // Address input 
  input [DWIDTH/8-1:0] wbe;  // write-byte-enable Only can write or read 16 bit at once
  input en;
  input clk;                  //T > 20ns make sure sram works

  output [DWIDTH-1:0] q;      //ok

//To issi asram
  inout  [DWIDTH-1:0] sram_dio;
  output [AWIDTH-1:0] sram_addr;        //ok
  
  output sram_oe_n; // write enter writing status, set oe to high for writing speed ok
  output sram_ce_n; // always low        ok                                            
  output sram_we_n; // write control     ok
  output sram_lb_n; // if read always low, if write depence on wbe ok
  output sram_ub_n; // if read always low, if write depence on wbe ok

  wire we;
  wire  [DWIDTH-1:0] sram_q;
  reg [DWIDTH-1:0] q_reg;
  
  //if any write, we = 1
  assign we = |wbe;

  assign sram_ce_n = ~en;
  assign sram_oe_n = we;         //if we output disable
  assign sram_we_n = ~we | ~clk; //half clk cycle write 
  // assign sram_lb_n = ~sram_we_n & ~wbe[0];
  // assign sram_ub_n = ~sram_we_n & ~wbe[1];
  assign sram_lb_n = 0; //Only can write or read 16 bit at once
  assign sram_ub_n = 0;

  assign sram_addr = addr;


  assign q = sram_q;


  //tri state buffer 
  genvar i;
  generate
    for (i = 0; i < DWIDTH; i = i + 1) begin
      //xilix IOBUF is low active output
      IOBUF  IOBUF_00 (
          .O(sram_q[i]),               // Buffer output
          .IO(sram_dio[i]),            // Buffer inout port (connect directly to top-level port)
          .I(d[i]),                    // Buffer input
          .T(~sram_oe_n)               // 3-state enable input, high=input, low=output
      );
    end
  endgenerate

endmodule