# ===== SoC address map =====
rtl/soc/soc_addr_map_pkg.sv

# ===== APB infrastructure =====
-f sim/filelists/apb.f

# ===== Peripheral address map and register packages =====
rtl/soc/apb_addr_map_pkg.sv

# ===== RV32 core =====
-f sim/filelists/rv32_core.f

# ===== Common =====
rtl/common/cdc_sync_2ff.sv
rtl/common/sync_fifo.sv
rtl/common/sync_fifo_buffer.sv

# ===== UART =====
rtl/peripherals/uart/baud_gen.sv
rtl/peripherals/uart/uart_tx_core.sv
rtl/peripherals/uart/uart_tx.sv
rtl/peripherals/uart/uart_rx_core.sv
rtl/peripherals/uart/uart_rx.sv
rtl/peripherals/uart/uart_wrapper.sv
rtl/peripherals/uart/apb_uart.sv

# ===== SoC integration =====
rtl/soc/apb_subsystem.sv
rtl/soc/addr_decoder.sv
rtl/soc/ram.sv
rtl/soc/soc_top.sv
