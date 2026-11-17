## Top: ebaz4205_top, app: da2, board: EBAZ4205 without the HELLOFPGA carrier.
## Connect the peripheral signals to DATA1/DATA2 with jumper wires.
## Connector signal numbers (DATAx_y) are not FPGA package pin names.
## I/O signals are 3.3 V. DATA1/DATA2 ground pins: 3, 4 or 12.
## Pin map reference: https://github.com/xjtuecho/EBAZ4205/wiki/Data-Connectors

## UART 115200 8N1, USB-UART adapter wired directly to DATA1.
## FPGA RX: DATA1_9 = C20 <- USB-UART TX.
## FPGA TX: DATA1_11 = H17 -> USB-UART RX.
set_property -dict { PACKAGE_PIN C20 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {uart_rx_pin_i}]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {uart_tx_pin_o}]

## DHT22 DATA: DATA1_7 = B19, 3.3-V open-drain bidirectional signal.
## Add an external 4.7 kOhm to 5.1 kOhm pull-up to 3.3 V at the sensor.
set_property -dict { PACKAGE_PIN B19 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {dht_io}]

## LCD1602/PCF8574: SDA = DATA2_7, SCL = DATA2_5.
## Open-drain I/O; use a 3.3-V bus pull-up. LCD address is 0x27 in da2.
set_property -dict { PACKAGE_PIN G20 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW PULLUP true } [get_ports {i2c_scl_io}]
set_property -dict { PACKAGE_PIN G19 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW PULLUP true } [get_ports {i2c_sda_io}]

## Active-low buzzer-enable button: DATA2_9.
set_property -dict { PACKAGE_PIN J19 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {key5_n_i}]

## Active-high carrier LED: DATA1_15 = H18; on when buzzer is enabled.
set_property -dict { PACKAGE_PIN H18 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {carrier_led_o}]

## Buzzer output: DATA1_13 = D20; GPIO gates the PL-generated 2-kHz tone.
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {buzzer_o}]

## EBAZ4205 onboard LEDs, active-low: W13 green heartbeat, W14 PL reset indicator.
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {led_green_no}]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW } [get_ports {led_red_no}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## PS7 FCLK0=100 MHz -> Clocking Wizard=70 MHz; generated BD constraints apply.
## PL reset is synchronized by Processor System Reset. The PS supervisor
## forwards the EBAZ4205 S2 button state into the PL reset path.
