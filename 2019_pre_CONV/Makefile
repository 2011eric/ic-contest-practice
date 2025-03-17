PATTERN=$1
TSMC=/usr/cad/designkit/digital/T13/CBDK_IC_Contest_v2.5/Verilog/tsmc13_neg.v
TSMC=/home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/Verilog/tsmc13_neg.v

.PHONY: syn
all:
run_rtl:
	vcs -R -sverilog -full64 testfixture.v CONV.v +define+FSDB +access+r +fsdbfile+CONV.fsdb -debug_access+all +v2k | tee rtl.log
syn:
	dc_shell-t -f syn.tcl | tee syn.log
run_syn:
	vcs -R -sverilog -full64 testfixture.v syn/CONV_syn.v +define+SDF +access+r +vcs+fsdbon \
	+fsdb+mda -v ${TSMC} +neg_tchk +max_delays | tee syn.log
