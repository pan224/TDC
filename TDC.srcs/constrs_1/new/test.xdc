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


# 主时钟约束
create_clock -period 5.000 -name sys_clk [get_ports SYS_CLK_P]
create_clock -period 2.500 -name clk_bufg [get_pins clk_wiz_0_inst/clk_out1]
create_clock -period 5.000 -name clk_100MHz [get_pins global_clock_reset_inst/CLK_OUT2]

# TDC 延迟链约束 - 设置为异步路径
set_false_path -from [get_pins line_tdc_inst/*/CO[*]] -to [get_pins line_tdc_inst/*/D]

# CARRY4 链约束
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets line_tdc_inst/dat_reg0[*]]

# 跨时钟域约束
set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks clk_bufg] \
    -group [get_clocks clk_100MHz]

# 动态相位调整约束
set_max_delay -from [get_pins phase_gen_inst/*/C] -to [get_pins tdc_top_inst/*/D] 10.000

# IDELAYE2 输出到 TDC 约束
set_max_delay -from [get_pins tdc_delay_ctrl_inst/IDELAYE2_*/DATAOUT] -to [get_pins tdc_top_inst/FDCE_INST2/D] 2.000

# 放宽 bubble_fix 时序
set_multicycle_path -setup 2 -from [get_pins bubble_fix_inst1/*] -to [get_pins latch2bin_inst1/*]
set_multicycle_path -hold 1 -from [get_pins bubble_fix_inst1/*] -to [get_pins latch2bin_inst1/*]、

# ============================================================================
# 跨时钟域约束 - cs_gap 信号从 clk_bufg 到 clk_100MHz
# ============================================================================

# cs_gap 是单 bit 控制信号，使用双触发器同步，允许一定的延迟
set_max_delay -from [get_pins tdc_top_inst/latch2bin_inst1/bin_cs_reg/C] \
              -to [get_pins eth_comm_ctrl_inst/cs_gap_sync1_reg/D] \
              -datapath_only 10.000

# # 或者更简洁的方式：将所有从 clk_bufg 到 clk_100MHz 的 cs_gap 路径设为异步
# set_false_path -from [get_pins tdc_top_inst/latch2bin_inst1/bin_cs_reg/C] \
#                -to [get_pins eth_comm_ctrl_inst/cs_gap_sync1_reg/D]