## Top: ebaz4205_top, app: da2, board: EBAZ4205 + HELLOFPGA carrier.
## Header DATAx_y numbers differ from FPGA package pin names.
## Signals and pull-ups use 3.3 V. PS7 BD supplies the clock and reset.
## DATA1 GND: pins 3, 4 or 12; DATA2/DATA3 GND: pins 3, 4 or 12.
## Pinout: https://github.com/xjtuecho/EBAZ4205/wiki/Data-Connectors

## UART 115200 8N1 through the expansion board Type-C/CH340.
## FPGA RX: DATA1_6 = H16 <- CH340 TX.
## FPGA TX: DATA1_11 = H17 -> CH340 RX.
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {uart_rx_pin_i}]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {uart_tx_pin_o}]

## DHT22 DATA: DATA3_5 = M19.  This is a 3.3-V open-drain, bidirectional
## signal.  Fit an external 4.7 kOhm to 5.1 kOhm pull-up to 3.3 V at the
## sensor; do not pull this pin up to 5 V.
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {dht_io}]

## LCD1602/PCF8574: SDA = DATA2_6/J18, SCL = DATA2_5/G20.
## Open-drain I/O; the FPGA drives only low. LCD address is 0x27 in da2.
set_property -dict { PACKAGE_PIN G20 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW PULLUP true } [get_ports {i2c_scl_io}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW PULLUP true } [get_ports {i2c_sda_io}]

## KEY5: DATA3_19 = V20, active-low.  It toggles buzzer permission.
set_property -dict { PACKAGE_PIN V20 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {key5_n_i}]

## One active-high carrier LED: DATA1_15/H18 = buzzer enabled.
set_property -dict { PACKAGE_PIN H18 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {carrier_led_o}]

## Passive carrier buzzer: DATA1_14/D18. GPIO[11] gates a PL-generated 2 kHz tone.
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {buzzer_o}]

## Main-board LED6, active-low: W13 green heartbeat, W14 PL reset asserted.
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {led_green_no}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {led_red_no}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## PS7 FCLK0=100 MHz -> Clocking Wizard=70 MHz; generated BD constraints apply.
## pl_rst_n is synchronized by Processor System Reset. KEY5 is GPIO input 0.
## S2 is PS MIO20: a running PS supervisor is needed to forward S2 to PL reset.
