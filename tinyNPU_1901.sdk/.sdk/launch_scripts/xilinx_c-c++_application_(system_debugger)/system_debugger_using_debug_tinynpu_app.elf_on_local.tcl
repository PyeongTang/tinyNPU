connect -url tcp:127.0.0.1:3121
source C:/Users/qwer/Desktop/work/tinyNPU_1901/tinyNPU_1901.sdk/design_1_wrapper_hw_platform_0/ps7_init.tcl
targets -set -nocase -filter {name =~"APU*" && jtag_cable_name =~ "Digilent Zybo Z7 210351B7BEACA"} -index 0
rst -system
after 3000
targets -set -filter {jtag_cable_name =~ "Digilent Zybo Z7 210351B7BEACA" && level==0} -index 1
fpga -file C:/Users/qwer/Desktop/work/tinyNPU_1901/tinyNPU_1901.sdk/design_1_wrapper_hw_platform_0/design_1_wrapper.bit
targets -set -nocase -filter {name =~"APU*" && jtag_cable_name =~ "Digilent Zybo Z7 210351B7BEACA"} -index 0
loadhw -hw C:/Users/qwer/Desktop/work/tinyNPU_1901/tinyNPU_1901.sdk/design_1_wrapper_hw_platform_0/system.hdf -mem-ranges [list {0x40000000 0xbfffffff}]
configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*" && jtag_cable_name =~ "Digilent Zybo Z7 210351B7BEACA"} -index 0
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "ARM*#0" && jtag_cable_name =~ "Digilent Zybo Z7 210351B7BEACA"} -index 0
dow C:/Users/qwer/Desktop/work/tinyNPU_1901/tinyNPU_1901.sdk/tinyNPU_app/Debug/tinyNPU_app.elf
configparams force-mem-access 0
targets -set -nocase -filter {name =~ "ARM*#0" && jtag_cable_name =~ "Digilent Zybo Z7 210351B7BEACA"} -index 0
con
