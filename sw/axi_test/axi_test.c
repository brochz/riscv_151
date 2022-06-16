#include "types.h"
#include "ascii.h"
#include "uart.h"
#include "memory_map.h"

#define BUF_LEN 128

#define SIZE 128

#define csr_tohost(csr_val) { \
  asm volatile ("csrw 0x51e,%[v]" :: [v]"r"(csr_val)); \
}

//array开头地址都是4_Byte对齐的, Why?
static int8_t array0[SIZE] = {0};
static int8_t array1[SIZE] = {0};

typedef void (*entry_t)(void);

// This simple test loops data from DMem to DDR and back
int main(int argc, char**argv) {
  int8_t buffer[BUF_LEN];
  int32_t len = SIZE;
  int32_t i;

  for (i = 0; i < len; i++) {
    array1[i] = i;
  }

  // Copy data from array1 from DMem to DDR at address 0x40_0000
  DMA_DIR = 1;
  DMA_DST_ADDR = 0x000000;  
  // shift right by 2 because the DMA uses word-level addressing to access DMem
  //那就是一次转移32bit?
  DMA_SRC_ADDR = (uint32_t)array1 >> 2;   //这个地址直接加到dmem上
  // shift right by 2 because we're sending 8b data on 32b data bus
  DMA_LEN = len >> 2;  // 可能len的单位为4byte把
  DMA_START = 1;       //不需要软件clear START, 就写个脉冲算啦
  //等待DMA_DONE
  while (!DMA_DONE);
  
  // Copy data from DDR at address 0x40_0000 to array0 from DMem
  DMA_DIR = 0;
  DMA_SRC_ADDR = 0x000000;
  // shift right by 2 because the DMA uses word-level addressing to access DMem
  DMA_DST_ADDR = (uint32_t)array0 >> 2;
  // shift right by 2 because we're sending 8b data on 32b data bus
  DMA_LEN = len >> 2;
  DMA_START = 1;
  while (!DMA_DONE);

  uint32_t num_mismatches = 0;

  // // Make sure that the two arrays match!
  for (i = 0; i < len; i++) {
    if (array0[i] != array1[i]) num_mismatches += 1;
  }

  if (num_mismatches == 0){
    csr_tohost(1);
  }
  else {
    csr_tohost(2);
  }
  return 0;
}
