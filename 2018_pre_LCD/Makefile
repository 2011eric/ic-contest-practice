#TSMC=/usr/cad/designkit/digital/T13/CBDK_IC_Contest_v2.5/Verilog/tsmc13_neg.v
TSMC=/home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/Verilog/tsmc13_neg.v

#SUB_DIR=2022_pre_JAM
DESIGN=LCD
DESIGN_FILE=LCD_CTRL.v
TESTBENCH=testfixture.v
PATTERN:=tb1
SRC=$(TESTBENCH) $(DESIGN_FILE)
SDFFILE=
# usage: make run_rtl PATTERN=P1

.PHONY: syn
all:
run_rtl: ${SRC}
	vcs -R -sverilog -full64 ${SRC} +define+$(PATTERN) +define+FSDB +access+r -debug_access+all +v2k | tee rtl.log
syn:
	dc_shell-t -f syn.tcl | tee syn.log
run_syn:
	vcs -R -sverilog -full64 ${TESTBENCH} "./syn/${DESIGN}_syn.v" +define+SDF +define+SDFFILE=\"./syn/${DESIGN}_syn.sdf\" +access+r +vcs+fsdbon \
	+fsdb+mda -v ${TSMC} +neg_tchk +max_delays | tee syn.log
