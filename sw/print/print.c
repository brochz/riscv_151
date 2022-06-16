#include "uart.h"
#include "ascii.h"
typedef void (*entry_t)(void);
int main()
{
  int i = 0;
  for(i = 0; i < 10; i++)
  {
    uwrite_int8s("Hello world!\r\n");
  }
  uint32_t bios = ascii_hex_to_uint32("40000000");
  entry_t start = (entry_t) (bios);
  start();
  return 0;
}


