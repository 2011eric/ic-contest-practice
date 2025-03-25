set DESIGN "SME"

set hdlin_translate_off_skip_text "TRUE"
set edifout_netlist_only "TRUE"
set verilogout_no_tri true
set high_fanout_net_threshold 0

sh mkdir -p syn
sh mkdir -p report

define_design_lib work -path ./work
set_host_options -max_cores 8



analyze -format sverilog "flist.sv"
elaborate $DESIGN
link

current_design [get_designs $DESIGN]
source -echo -verbose ${DESIGN}.sdc

compile_ultra -retime

write -format verilog -hierarchy -output syn/${DESIGN}_syn.v
write -format ddc -hierarchy -output syn/${DESIGN}_syn.ddc
write_sdf -version 2.1 syn/${DESIGN}_syn.sdf
report_area -hier > report/area.log
report_timing > report/timing.log
report_qor   >  report/SME_syn.qor
