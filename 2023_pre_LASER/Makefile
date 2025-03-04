PATTERN=$1
TSMC=/usr/cad/designkit/digital/T13/CBDK_IC_Contest_v2.5/Verilog/tsmc13_neg.v
all:
run_rtl:
	vcs -R -sverilog -full64 tb.sv LASER.v +define+P${PATTERN}+USECOLOR +access+r +fsdb+mda +fsdbfile+LASER.fsdb +vcs+fsdbon
syn:
	dc_shell-t -f dc_syn.tcl
run_syn:
	vcs -R -sverilog tb.sv LASER_syn.v +define+SDF +access+r +vcs+fsdbon \
	+fsdb+mda +fsdbfile+LASER.fsdb -v ${TSMC} +maxdelays +neg_tchk
