module fpga_wrapper_ (
    sys_clk,
    rst,
    FPGA_SERIAL_RX,
    FPGA_SERIAL_TX
);

input sys_clk;
input rst;
input FPGA_SERIAL_RX;
output FPGA_SERIAL_TX;


wire clk;


//Xilinx MMCM IP
mmcm100_50 mmcm
(
    // Clock out ports
    .clk_out1(clk),     // output clk_out1
   // Clock in ports
    .clk_in1(sys_clk)
);      // input clk_in1

Riscv151 
#(
    .CPU_CLOCK_FREQ (50_000_000         ),
    .RESET_PC       (32'h4000_0000      ),
    .BAUD_RATE      (115200             ),
    .BIOS_MIF_HEX   ("bios151v3.mif"    )
)
CPU(
    .clk            (clk            ),
    .rst            (rst            ),
    .FPGA_SERIAL_RX (FPGA_SERIAL_RX ),
    .FPGA_SERIAL_TX (FPGA_SERIAL_TX )
);





endmodule