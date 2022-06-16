.section    .start
.global     _start

_start:

# Follow a convention
# x1 = result register 1
# x2 = result register 2
# x3 = address register 1
# x4 = address register 2 
# x10 = argument 1 register
# x11 = argument 2 register
# x20 = flag register

# Test Vector
add x1, x0, x0 #clear x1 register
la x3, array  # start address of array(include)
la x4, array_end #end address of array(exclude)

sum:
	beq  x3, x4, Done #if x3 == x4, Done
	lw   x2, 0(x3) #load number 

	add  x1, x1, x2 #add number to sum
	addi x3, x3, 4 #add x3
	j sum  # jump to sum

Done:
	li x20, 1 # x20 =1 set the flag 
Loop: j Loop

array:
.word 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17
array_end:

