#! python3
import os
import sys

if __name__ == "__main__":
  with open("hex.bin", "wb") as f:
    f.write(int(sys.argv[1], base=16).to_bytes(int(len(sys.argv[1])/2), 'little'))
  os.system("riscv64-unknown-elf-objdump -Mnumeric -D -b binary -mriscv  hex.bin | grep 0:")
