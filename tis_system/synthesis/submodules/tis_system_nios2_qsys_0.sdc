# Legal Notice: (C)2024 Altera Corporation. All rights reserved.  Your
# use of Altera Corporation's design tools, logic functions and other
# software and tools, and its AMPP partner logic functions, and any
# output files any of the foregoing (including device programming or
# simulation files), and any associated documentation or information are
# expressly subject to the terms and conditions of the Altera Program
# License Subscription Agreement or other applicable license agreement,
# including, without limitation, that your use is for the sole purpose
# of programming logic devices manufactured by Altera and sold by Altera
# or its authorized distributors.  Please refer to the applicable
# agreement for further details.

#**************************************************************
# Timequest JTAG clock definition
#   Uncommenting the following lines will define the JTAG
#   clock in TimeQuest Timing Analyzer
#**************************************************************

#create_clock -period 10MHz {altera_reserved_tck}
#set_clock_groups -asynchronous -group {altera_reserved_tck}

#**************************************************************
# Set TCL Path Variables 
#**************************************************************

set 	tis_system_nios2_qsys_0 	tis_system_nios2_qsys_0:*
set 	tis_system_nios2_qsys_0_oci 	tis_system_nios2_qsys_0_nios2_oci:the_tis_system_nios2_qsys_0_nios2_oci
set 	tis_system_nios2_qsys_0_oci_break 	tis_system_nios2_qsys_0_nios2_oci_break:the_tis_system_nios2_qsys_0_nios2_oci_break
set 	tis_system_nios2_qsys_0_ocimem 	tis_system_nios2_qsys_0_nios2_ocimem:the_tis_system_nios2_qsys_0_nios2_ocimem
set 	tis_system_nios2_qsys_0_oci_debug 	tis_system_nios2_qsys_0_nios2_oci_debug:the_tis_system_nios2_qsys_0_nios2_oci_debug
set 	tis_system_nios2_qsys_0_wrapper 	tis_system_nios2_qsys_0_jtag_debug_module_wrapper:the_tis_system_nios2_qsys_0_jtag_debug_module_wrapper
set 	tis_system_nios2_qsys_0_jtag_tck 	tis_system_nios2_qsys_0_jtag_debug_module_tck:the_tis_system_nios2_qsys_0_jtag_debug_module_tck
set 	tis_system_nios2_qsys_0_jtag_sysclk 	tis_system_nios2_qsys_0_jtag_debug_module_sysclk:the_tis_system_nios2_qsys_0_jtag_debug_module_sysclk
set 	tis_system_nios2_qsys_0_oci_path 	 [format "%s|%s" $tis_system_nios2_qsys_0 $tis_system_nios2_qsys_0_oci]
set 	tis_system_nios2_qsys_0_oci_break_path 	 [format "%s|%s" $tis_system_nios2_qsys_0_oci_path $tis_system_nios2_qsys_0_oci_break]
set 	tis_system_nios2_qsys_0_ocimem_path 	 [format "%s|%s" $tis_system_nios2_qsys_0_oci_path $tis_system_nios2_qsys_0_ocimem]
set 	tis_system_nios2_qsys_0_oci_debug_path 	 [format "%s|%s" $tis_system_nios2_qsys_0_oci_path $tis_system_nios2_qsys_0_oci_debug]
set 	tis_system_nios2_qsys_0_jtag_tck_path 	 [format "%s|%s|%s" $tis_system_nios2_qsys_0_oci_path $tis_system_nios2_qsys_0_wrapper $tis_system_nios2_qsys_0_jtag_tck]
set 	tis_system_nios2_qsys_0_jtag_sysclk_path 	 [format "%s|%s|%s" $tis_system_nios2_qsys_0_oci_path $tis_system_nios2_qsys_0_wrapper $tis_system_nios2_qsys_0_jtag_sysclk]
set 	tis_system_nios2_qsys_0_jtag_sr 	 [format "%s|*sr" $tis_system_nios2_qsys_0_jtag_tck_path]

#**************************************************************
# Set False Paths
#**************************************************************

set_false_path -from [get_keepers *$tis_system_nios2_qsys_0_oci_break_path|break_readreg*] -to [get_keepers *$tis_system_nios2_qsys_0_jtag_sr*]
set_false_path -from [get_keepers *$tis_system_nios2_qsys_0_oci_debug_path|*resetlatch]     -to [get_keepers *$tis_system_nios2_qsys_0_jtag_sr[33]]
set_false_path -from [get_keepers *$tis_system_nios2_qsys_0_oci_debug_path|monitor_ready]  -to [get_keepers *$tis_system_nios2_qsys_0_jtag_sr[0]]
set_false_path -from [get_keepers *$tis_system_nios2_qsys_0_oci_debug_path|monitor_error]  -to [get_keepers *$tis_system_nios2_qsys_0_jtag_sr[34]]
set_false_path -from [get_keepers *$tis_system_nios2_qsys_0_ocimem_path|*MonDReg*] -to [get_keepers *$tis_system_nios2_qsys_0_jtag_sr*]
set_false_path -from *$tis_system_nios2_qsys_0_jtag_sr*    -to *$tis_system_nios2_qsys_0_jtag_sysclk_path|*jdo*
set_false_path -from sld_hub:*|irf_reg* -to *$tis_system_nios2_qsys_0_jtag_sysclk_path|ir*
set_false_path -from sld_hub:*|sld_shadow_jsm:shadow_jsm|state[1] -to *$tis_system_nios2_qsys_0_oci_debug_path|monitor_go
