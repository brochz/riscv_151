file_in =  "../../../sw/lenet_weight/lenet_weight.mif"
file_out = "weight16.mif"

f_in = open(file_in, "r")
f_out = open(file_out, "w")

lines = f_in.readlines()
for line in lines:
    f_out.write(line[4:]) 
    f_out.write(line[:4]+"\n")
