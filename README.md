根据Berkeley EECS151 FPGA的课程设计要求, 设计和实现了一个三级流水线的RISC-V(RV32I) CPU并将和UART集成。
进一步集成CNN加速器和DMA，系统中使用AXI总线进行数据交互。因为没有实验要求的PYNQ板子，设计在EGO1 FPGA上实现, 
同时课程设中的DRAM也改成了片外的SRAM。下面是整个系统框图的overview。

文件路径说明:

hw/                                #rtl代码以及testbench
  ...
sw/                                #汇编以及C程序
  ...
scripts/                           #串口程序和数据下载脚本
  ...
