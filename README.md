根据Berkeley EECS151 FPGA的课程设计要求, 设计和实现了一个三级流水线的RISC-V(RV32I) CPU并将和UART集成。
进一步集成CNN加速器和DMA，系统中使用AXI总线进行数据交互。因为没有实验要求的PYNQ板子，该实现在依元素EGO1 FPGA(https://e-elements.readthedocs.io/zh/ego1_v2.2/EGo11.html)上测试, 
同时设计中的DRAM也改成了片外的SRAM。下面是整个系统框图的overview。

![image](https://user-images.githubusercontent.com/44032370/173981697-3cc9f3bc-084a-424b-82ad-1e2284d5bbc9.png)


文件路径说明:

  hw/...                                #rtl代码以及testbench

  sw/...                                #汇编以及C程序

  scripts/...                           #串口程序和数据下载脚本

  
  
