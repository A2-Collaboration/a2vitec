# call this batch file with Xilinx Impact tool,
# e.g. `impact -batch generate_vitek_xsvf.cmd`
# It first generates a PROM file from the vitek_fpga_x3s1000.bit file,
# and then a file "vitek_fpga_prom.xsvf" which
# can be "played" via the `playxsvf` tool

# see also http://www.xilinx.com/support/documentation/sw_manuals/xilinx13_1/pim_r_examples.htm
# for impact batch file examples

# generate a mcs file from the bitstream vitek_fpga_xc3s1000.bit
setMode -pff
setSubmode -pffserial
addPromDevice -p 1 -name xcf04s
addDesign -version 0 -name 0
addDeviceChain -index 0
addDevice -p 1 -file vitek_fpga_xc3s1000.bit
generate -format mcs -fillvalue FF -output vitek_fpga_xcf04s.mcs

# generate a xsvf file which loads the mcs file into the PROM
setMode -bs
addDevice -p 1 -sprom xcf04s -file vitek_fpga_xcf04s.mcs
# the bitstream here is bypassed, since only the PROM is programmed
addDevice -p 2 -file vitek_fpga_xc3s1000.bit
setCable -port xsvf -file "vitek_fpga_prom.xsvf"
# erase and verify seems to be a good idea
program -e -v -p 1 -loadfpga
closeCable
quit
