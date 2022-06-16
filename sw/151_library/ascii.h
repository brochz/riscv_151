#ifndef ASCII_H_
#define ASCII_H_

#include "types.h"

//##可以把marco的变量和字符串分隔开, 这样编译器还是能够认识macro变量的名字
#define DECLARE_FROM_ASCII_HEX(type) \
type##_t ascii_hex_to_##type(const char* s);

//#号只能出现在replacement list
//n会被转换成一个string literal,变成 = print("n"),注意是带双引号
#define PRINT_INT(n) print(#n)n nn n##n //nn不会被替换, n##n可以

DECLARE_FROM_ASCII_HEX(uint8)
DECLARE_FROM_ASCII_HEX(uint16)
DECLARE_FROM_ASCII_HEX(uint32)

#define DECLARE_FROM_ASCII_DEC(type) \
type##_t ascii_dec_to_##type(const char* s);

DECLARE_FROM_ASCII_DEC(uint8)
DECLARE_FROM_ASCII_DEC(uint16)
DECLARE_FROM_ASCII_DEC(uint32)

#define DECLARE_TO_ASCII_HEX(type) \
int8_t* type##_to_ascii_hex(type##_t x, int8_t* buffer, uint32_t n);

DECLARE_TO_ASCII_HEX(uint8)
DECLARE_TO_ASCII_HEX(uint16)
DECLARE_TO_ASCII_HEX(uint32)

#endif
