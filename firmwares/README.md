A2 Firmware Archive
===================

This folder contains firmware images considered well-tested and
working. The filenames should be as precise as possible, maybe
correspond to the filename to the VHDL top-level entity.

How to program the FPGA PROM on the VITEC over VME?
---------------------------------------------------

The programming is based on the
[Xilinx XAPP058](http://www.xilinx.com/support/documentation/application_notes/xapp058.pdf).
There the whole process is described in great detail, the only
modification of the supplied code is the setting of the corresponding
JTAG signals TCK, TDI, TMS and reading TDO over VME. This is achieved
by using the "Port Mode" of the CPLD, which allows for accessing the
FPGA JTAG line independently.

Ensure that the modified `playxsvf` binary from
[a2vme](https://github.com/A2-Collaboration/a2vme) is compiled
(usually this binary is already available on the VME CPUs in
`/opt/a2vme/build/bin`) and that you have a Xilinx Toolchain
available.

The following steps should guide you through the process:

1. Run Xilinx Impact inside this directory with `impact -batch
generate_vitec_xsvf.cmd`. This batch file generates the file
`vitec_fpga_prom.xsvf` (among other files) from the bitstream
`vitec_fpga_xc3s1000.bit` (use the gzipped version if you 
don't have a better one)

2. Copy `vitec_fpga_prom.xsvf` to `/opt/vitec/fpga` on the VME CPUs, but
give it a version number (maybe the short hash of the a2fpga commit?).

3. Run as root on the VME CPU whose VITEC card should be reprogrammed:
`playxsvf /opt/vitec/fpga/vitec_fpga_prom_[VERSION NUMBER].xsvf`. This 
takes about 60 s to finish.
