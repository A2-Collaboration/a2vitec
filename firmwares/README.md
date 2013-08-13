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
generate_vitek_xsvf.cmd`. This batch file generates the file
`vitek_fpga_prom.xsvf` (among other files) from the bitstream
`vitek_fpga_xc3s1000.bit`.

2. Copy `vitek_fpga_prom.xsvf` to `/opt/a2vme/build` on the VME CPUs.

3. Run as root on the VME CPU whose VITEC card should be reprogrammed:
`playxsvf /opt/a2vme/build/vitek_fpga_prom.xsvf`. This takes max. 60 s
to finish.
