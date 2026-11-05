## Top: ebaz4205_top; existing block design: ps7_fclk.
## All signal levels/pull-ups must be 3.3 V. Power and GND are additional wires.

## DATA1 header pin numbers are distinct from FPGA package pin names.
## FPGA RX: DATA1_5  = package A20 <- USB-UART adapter TX.
## FPGA TX: DATA1_11 = package H17 -> USB-UART adapter RX.
## Common GND: DATA1_3, DATA1_4 or DATA1_12 -> USB-UART adapter GND.
## Pinout: https://github.com/xjtuecho/EBAZ4205/wiki/Data-Connectors
set_property -dict { PACKAGE_PIN A20 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {uart_rx_pin_i}]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {uart_tx_pin_o}]

## Existing main-board LED6 cathodes are active-low, no header wires needed.
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {led_green_no}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {led_red_no}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## pl_clk=70 MHz and pl_rst_n come from the existing PS/clock/reset BD.
## Its generated constraints cover the internal clock and PS fixed-I/O/DDR.
## S2 is PS MIO20: keep pl_supervisor running to use S2 as the SoC reset.
