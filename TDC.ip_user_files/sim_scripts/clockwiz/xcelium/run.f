-makelib xcelium_lib/xpm -sv \
  "D:/software/vivado/Vivado/2020.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
  "D:/software/vivado/Vivado/2020.1/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
-endlib
-makelib xcelium_lib/xpm \
  "D:/software/vivado/Vivado/2020.1/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../TDC.srcs/sources_1/ip/clockwiz/clockwiz_clk_wiz.v" \
  "../../../../TDC.srcs/sources_1/ip/clockwiz/clockwiz.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  glbl.v
-endlib

