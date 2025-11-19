#-------------------- ayatem pins ---------------
# --system reset active HIGH
set_property PACKAGE_PIN W19 [get_ports CPU_RESET]
set_property IOSTANDARD LVCMOS33 [get_ports CPU_RESET]

# PadFunction: IO_L12P_T1_MRCC_33
#set_property VCCAUX_IO DONTCARE [get_ports SYS_CLK_P]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports SYS_CLK_P]

# --system clk 200MHz
set_property PACKAGE_PIN AD12 [get_ports SYS_CLK_P]
set_property PACKAGE_PIN AD11 [get_ports SYS_CLK_N]
set_property IOSTANDARD DIFF_SSTL15 [get_ports SYS_CLK_P]
set_property IOSTANDARD DIFF_SSTL15 [get_ports SYS_CLK_N]

# 125MHz clock, for GTP/GTH/GTX
set_property PACKAGE_PIN U8 [get_ports {SGMIICLK_Q0_P}] 
set_property PACKAGE_PIN U7 [get_ports {SGMIICLK_Q0_N}] 

# Pins for GBE
set_property PACKAGE_PIN A27      [get_ports PHY_RESET_N]
set_property IOSTANDARD  LVCMOS25 [get_ports PHY_RESET_N]
set_property PACKAGE_PIN A26      [get_ports MDIO]
set_property IOSTANDARD  LVCMOS25 [get_ports MDIO]
set_property PACKAGE_PIN C26      [get_ports MDC]
set_property IOSTANDARD  LVCMOS25 [get_ports MDC]

set_property PACKAGE_PIN G29      [get_ports RGMII_RXD[3]]
set_property PACKAGE_PIN E30      [get_ports RGMII_RXD[2]]
set_property PACKAGE_PIN E29      [get_ports RGMII_RXD[1]]
set_property PACKAGE_PIN G28      [get_ports RGMII_RXD[0]]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_RXD[3]]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_RXD[2]]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_RXD[1]]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_RXD[0]]
set_property PACKAGE_PIN C27      [get_ports RGMII_TXD[3]]
set_property PACKAGE_PIN A30      [get_ports RGMII_TXD[2]]
set_property PACKAGE_PIN B29      [get_ports RGMII_TXD[1]]
set_property PACKAGE_PIN C30      [get_ports RGMII_TXD[0]]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_TXD[3]]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_TXD[2]]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_TXD[1]]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_TXD[0]]
set_property PACKAGE_PIN D29      [get_ports RGMII_TX_CTL]
set_property PACKAGE_PIN C25      [get_ports RGMII_TXC]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_TX_CTL]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_TXC]
set_property PACKAGE_PIN G30      [get_ports RGMII_RX_CTL]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_RX_CTL]
set_property PACKAGE_PIN D27      [get_ports RGMII_RXC]
set_property IOSTANDARD  LVCMOS25 [get_ports RGMII_RXC]



# ============================================================================
# 确保 CARRY4 链连续性
set_property LOC SLICE_X0Y0 [get_cells {tdc_top_inst/line_tdc_inst/genblk1[0].carry4_first.CARRY4_INST}]
