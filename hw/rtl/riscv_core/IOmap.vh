`define UART_CONTROL_R          32'h80000000
`define UART_DATA_R             32'h80000004
`define UART_DATA_W             32'h80000008
`define COUNTER_CYCLE_R         32'h80000010
`define COUNTER_INS_R           32'h80000014
`define COUNTER_RST_W           32'h80000018


`define DMA_CONTROL_W           32'h80000030
`define DMA_STATUS_R            32'h80000034
`define DMA_DIRECT_W            32'h80000038
`define DMA_SRCADDR_W           32'h8000003C
`define DMA_DESADDR_W           32'h80000040
`define DMA_TLEN_W              32'h80000044


`define XCEL_CONTROL_W          32'h80000050
`define XCEL_STATUS_R           32'h80000054
`define XCEL_IFMADDR_W          32'h80000058
`define XCEL_WEIADDR_W          32'h8000005c
`define XCEL_OFMADDR_W          32'h80000060
`define XCEL_IFMDIMS_W          32'h80000064
`define XCEL_IFMDPTH_W          32'h80000068
`define XCEL_OFMDIMS_W          32'h8000006c
`define XCEL_OFMDPTH_W          32'h80000070