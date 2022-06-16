#include "string.h"

#define csr_tohost(csr_val) { \
    asm volatile ("csrw 0x51e,%[v]" :: [v]"r"(csr_val)); \
}

int main(void) {
    csr_tohost(0);
    //这个数组不能太长,不然要call memset函数，不知道为什么...
    char str[10] = "123456789";

    if (strcmp(str ,"123456789") == 0) {
        // pass
        csr_tohost(1);
    } else {
        // fail code 2
        csr_tohost(2);
    }

    // spin
    for( ; ; ) {
        asm volatile ("nop");
    }
}
