-- Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2020.1 (win64) Build 2902540 Wed May 27 19:54:49 MDT 2020
-- Date        : Thu Nov 20 18:50:59 2025
-- Host        : DESKTOP-RBHFTC6 running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               d:/project/vivado_work/TDC/TDC/TDC.srcs/sources_1/ip/clk_wiz_phase/clk_wiz_phase_stub.vhdl
-- Design      : clk_wiz_phase
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7k325tffv900-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_wiz_phase is
  Port ( 
    clk_out1 : out STD_LOGIC;
    psclk : in STD_LOGIC;
    psen : in STD_LOGIC;
    psincdec : in STD_LOGIC;
    psdone : out STD_LOGIC;
    reset : in STD_LOGIC;
    clk_in1 : in STD_LOGIC
  );

end clk_wiz_phase;

architecture stub of clk_wiz_phase is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_out1,psclk,psen,psincdec,psdone,reset,clk_in1";
begin
end;
