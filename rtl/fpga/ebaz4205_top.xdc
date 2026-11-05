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

## PIR OUT: DATA2_7 = G19 -> GPIO[5], active-high.
set_property -dict { PACKAGE_PIN G19 IOSTANDARD LVCMOS33 PULLDOWN true } [get_ports {pir_i}]

## LCD1602/PCF8574: SDA = DATA2_6/J18, SCL = DATA2_5/G20.
## Open-drain I/O; the FPGA drives only low. LCD address is 0x27 in da2.
set_property -dict { PACKAGE_PIN G20 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW PULLUP true } [get_ports {i2c_scl_io}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW PULLUP true } [get_ports {i2c_sda_io}]

## Carrier keys -> GPIO[4:0], active-low, in KEY1..KEY5 order.
## KEY1: DATA3_18/T19; KEY2: DATA3_15/P19; KEY3: DATA3_17/U20.
## KEY4: DATA3_20/U19; KEY5: DATA3_19/V20.
## App: KEY3 backlight, KEY4 LCD retry, KEY5 sound on/off; KEY1/KEY2 unused.
set_property -dict { PACKAGE_PIN T19 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {key_n_i[0]}]
set_property -dict { PACKAGE_PIN P19 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {key_n_i[1]}]
set_property -dict { PACKAGE_PIN U20 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {key_n_i[2]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {key_n_i[3]}]
set_property -dict { PACKAGE_PIN V20 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {key_n_i[4]}]

## Active-high carrier LEDs <- GPIO[10:8].
## LED0: DATA1_18/E19 = alarm; LED1: DATA1_20/K17 = armed.
## LED2: DATA1_15/H18 = sound enabled (not the current beep phase).
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {carrier_led_o[0]}]
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {carrier_led_o[1]}]
set_property -dict { PACKAGE_PIN H18 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {carrier_led_o[2]}]

## Passive carrier buzzer: DATA1_14/D18. GPIO[11] gates a PL-generated 2 kHz tone.
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {buzzer_o}]

## Main-board LED6, active-low: W13 green heartbeat, W14 reset/key/trap.
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {led_green_no}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {led_red_no}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## PS7 FCLK0=100 MHz -> Clocking Wizard=70 MHz; generated BD constraints apply.
## pl_rst_n is synchronized by Processor System Reset. KEY5 is only GPIO.
## S2 is PS MIO20: a running PS supervisor is needed to forward S2 to PL reset.
