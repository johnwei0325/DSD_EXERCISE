############################################
# import design
############################################
set DESIGN "GSIM"
set Report_dir "Report"
set Netlist_dir "Netlist"
sh mkdir -p $Report_dir
sh mkdir -p $Netlist_dir

analyze -format verilog "./GSIM.v"
elaborate $DESIGN
link
current_design $DESIGN


############################################
# source sdc
############################################
source -echo -verbose ./GSIM_DC.sdc


############################################
# compile
############################################
uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
compile_ultra
compile -inc


############################################
# output design
############################################
current_design $DESIGN

set hdlin_enable_presto_for_vhdl "TRUE"
set sh_enable_line_editing true
set sh_line_editing_mode emacs
history keep 100
alias h history

set bus_inference_style {%s[%d]}
set bus_naming_style {%s[%d]}
set hdlout_internal_busses true
change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _} -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]} -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive
change_names -hierarchy -rules name_rule

remove_unconnected_ports -blast buses [get_cells -hierarchical *]
set verilogout_higher_designs_first true
write -format ddc      -hierarchy -output "./$Netlist_dir/${DESIGN}_syn.ddc"
write -format verilog  -hierarchy -output "./$Netlist_dir/${DESIGN}_syn.v"
write_sdf -version 3.0 -context verilog ./$Netlist_dir/${DESIGN}_syn.sdf
write_sdc ./$Netlist_dir/${DESIGN}_syn.sdc -version 1.8
report_timing -delay_type max > "./$Report_dir/${DESIGN}_timing_max.rpt"
report_timing -delay_type min > "./$Report_dir/${DESIGN}_timing_min.rpt"
report_area > "./$Report_dir/${DESIGN}_area.rpt"

report_timing
report_area