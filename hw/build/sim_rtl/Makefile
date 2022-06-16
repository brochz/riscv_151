
VERILOG_DIRS := ../../rtl
TB_DIR			 := ../../tb
SW_DIR			 := ../../../sw#Leadind spaces are ignored, Ending spaces are included

VERILOG_DIRS += $(filter-out %.v, $(wildcard ../../rtl/*)) 
VERILOG_SRCS = $(foreach dir, $(VERILOG_DIRS), $(wildcard $(dir)/*.v))

# VERILOG_SRCS := $(wildcard src/*.v)
# VERILOG_SRCS += $(wildcard src/io_circuits/*.v)
# VERILOG_SRCS += $(wildcard src/riscv_core/*.v)
# VERILOG_SRCS += $(wildcard src/accelerator/*.v)

VERILOG_SIMS := $(wildcard $(TB_DIR)/*.v)


tb := assembly_testbench

ifeq ($(tb), assembly_testbench)
sw   = assembly_tests
else ifeq ($(tb), echo_testbench)
sw   = echo
else ifeq ($(tb), c_testbench)
sw = c_test
else ifeq ($(tb), isa_testbench)
sw = riscv-isa-tests
test = all
else
test = $(sw)
endif



BIOS_MIF := $(SW_DIR)/bios151v3/bios151v3.mif
SW_MIF   := $(SW_DIR)/$(sw)/*.mif
SW_SRCS  := $(wildcard $(SW_DIR)/$(sw)/*.h)
SW_SRCS  += $(wildcard $(SW_DIR)/$(sw)/*.c)
SW_SRCS  += $(wildcard $(SW_DIR)/$(sw)/*.s)
SW_SRCS  += $(wildcard $(SW_DIR)/$(sw)/*.ld)

$(BIOS_MIF):
		cd $(SW_DIR)/bios151v3 && make > /dev/null

$(SW_MIF): $(SW_SRCS)
		cd $(SW_DIR)/$(sw) && make 

$(sw): $(SW_MIF)

# iverilog simulation
sim_exec = $(tb).out
sim_vcd  = $(tb).vcd

IV_FLAGS := -Wimplicit -Winfloop -Wfloating-nets -DSIMULATION
IV_INCLU :=  $(foreach dir, $(VERILOG_DIRS) $(TB_DIR), -I $(dir))

iverilog-compile $(sim_exec): $(VERILOG_SRCS) $(VERILOG_SIMS)
		iverilog $(IV_FLAGS) -o$(sim_exec) $(IV_INCLU) -s $(tb) $(VERILOG_SRCS) $(VERILOG_SIMS)
		
# Full ISA test suit (exclude fence_i)
isa_tests = \
	addi \
	add \
	andi \
	and \
	auipc \
	beq \
	bge \
	bgeu \
	blt \
	bltu \
	bne \
	jal \
	jalr \
	lb \
	lbu \
	lh \
	lhu \
	lui \
	lw \
	ori \
	or \
	sb \
	sh \
	simple \
	slli \
	sll \
	slti \
	sltiu \
	slt \
	sltu \
	srai \
	sra \
	srli \
	srl \
	sub \
	sw \
	xori \
	xor \

#"tee" command reads the standard input and writes it to both the standard output
#and one or more files.

iverilog-sim $(sim_vcd): $(sim_exec) $(BIOS_MIF) $(sw)
	cp $(BIOS_MIF) ./
	if [ "$(sw)" != "" ] ; then \
		cp $(SW_MIF) ./ ; \
	fi
	if [ "$(tb)" = "isa_testbench" -a "$(test)" = "all" ] ; then \
		for inst in $(isa_tests) ; do \
			vvp ./$(sim_exec) +MIF_FILE=$$inst.mif | tee -a output.log ; \
		done ; \
		sed -n '/\[[a-zA-Z]*\]/p' output.log ; \
	else \
		vvp ./$(sim_exec) +MIF_FILE=$(test).mif ; \
	fi


wave: $(sim_vcd)
	gtkwave $(sim_vcd)





































# Vivado
proj := z1top
Z1TOP_XPR = $(proj)_proj/$(proj)_proj.xpr

clk := 20
port_number := 3121

$(Z1TOP_XPR): $(VERILOG_SRCS) $(BIOS_MIF)
		vivado -mode batch -source scripts/build_project.tcl -tclargs $(proj) $(clk)

.PHONY: build-project
build-project: $(Z1TOP_XPR)

.PHONY: sim
sim: $(sw) $(BIOS_MIF)
		vivado -mode batch -source scripts/sim.tcl -tclargs $(proj) $(tb) $(sw) $(test) | tee output.log
		sed -n '/\[[a-zA-Z]*\]/p' output.log ; \

.PHONY: write-bitstream
write-bitstream: $(Z1TOP_XPR)
		vivado -mode batch -source scripts/write_bitstream.tcl -tclargs $(proj) $(clk)

.PHONY: program-fpga
program-fpga:
		vivado -mode batch -source scripts/program_fpga.tcl -tclargs $(bs)

.PHONY: init-arm
init-arm:
		xsdb scripts/init_arm.tcl $(port_number)

.PHONY: clean
# "make clean" won't remove your project folders
clean:
		rm -rf *.log *.jou *.str *.vcd *.out *.mif NA

.PHONY: veryclean
# "make veryclean" removes the project folders and bitstream files
veryclean:
		rm -rf *.log *.jou *.str *.vcd *.out *.mif NA z1top* bitstream_files

