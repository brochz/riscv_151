#!/usr/bin/env python3
# ported from /home/ff/eecs151/tools-151/bin/coe_to_serial
import os
import serial
import sys
import time

from serial.serialutil import Timeout

# Windows
if os.name == 'nt':
    ser = serial.Serial()
    ser.timeout = 0.01
    ser.baudrate = 115200
    ser.port = 'COM7' # CHANGE THIS COM PORT
    ser.open()
else:
    ser = serial.Serial('/dev/ttyUSB0')
    ser.baudrate = 115200

def store_u32(data, address):
    data = f"{data:08x}"   #8 test data 
    address = f"{address:08x}"
    string = f"sw {data} {address} "   #the string send to FPGA 
    #sending data 
    for c in string:
        ser.write(c.encode("utf-8")) 
        time.sleep(0.01)         #FPGA UART has only 1 byte rx buffer
    #display result  
    respons = ser.read(100)
    print(respons)
    


def load_u32(address):
    string = f"lw {address:08x} "    #send load string to FPGA
    for c in string:
        ser.write(c.encode("utf-8")) 
        time.sleep(0.01)
    #display result 
    respons = ser.read(100)
    print(respons)

    return int(respons.decode("utf-8").split(":")[1][:8], 16)


#clear last command 
ser.write(b"\r\n")

file_name = "lenet_weight.mif"
length = 3453 #count by word 3453
#Store weight to dmem first
with open(file_name, "r") as f:
    lines = f.readlines()
    for i, line in enumerate(lines):
        print(f"Writing to dmem: {i}/{length}", end=" ")
        store_u32(int(line, 16), i*4 + 0X10000000)
        if i == length - 1:
            break

# #Check data written to dmem
# with open(file_name, "r") as f:
#     lines = f.readlines()
#     for i, line in enumerate(lines):
#         r = load_u32(i*4 + 0X10000000)
#         if(r != int(line, 16)):
#             print("DMEM ERROR!")
#             exit()
#         if i == length - 1:
#             break

print("Dmem data write done!")

#set dma register dmem -> sram
store_u32(1         , 0x80000038) #DMA_DIR 
store_u32(0X10000000, 0x8000003c) #SRC ADDR
store_u32(0x00000000, 0x80000040) #DST ADDR
store_u32(length    , 0x80000044) #DMA LEN
store_u32(0x00000001, 0x80000030) #DMA START

time.sleep(1)
#set dma register sram -> dmem
store_u32(0         , 0x80000038) #DMA_DIR 
store_u32(0x00000000, 0x8000003c) #SRC ADDR
store_u32(0x10000000+length, 0x80000040) #DST ADDR
store_u32(length    , 0x80000044) #DMA LEN
store_u32(0x00000001, 0x80000030) #DMA START
time.sleep(1)



#check data is same
for i in range(length):
    print(f"Checking: {i}/{length}", end=" ")
    r1 = load_u32(i*4 + 0X10000000)
    r2 = load_u32(i*4 + 0X10000000 + length*4) 
    if(r1 != r2):
        print("DMA OR SRAM ERROR!")
        exit()

print("...Data write to sram successed!...")
    