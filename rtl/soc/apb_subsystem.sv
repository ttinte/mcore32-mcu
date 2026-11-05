//-----------------------------------------------------------------------------
//  Module   : apb_subsystem
//  Children : apb_master, apb_interconnect, apb_uart, apb_timer, apb_i2c, apb_gpio
//
//  Description:
//     Connects CPU requests to APB peripherals.
//     To add a peripheral: instantiate its slave on apb_peripherals_bus[IDX],
//     expose external pins, update apb_addr_map and add its register map to firmware.
//     Peripheral IRQ outputs are unused; the CPU supports synchronous traps only.
//
//-----------------------------------------------------------------------------

module apb_subsystem #(
    parameter int unsigned CLOCK_RATE = 100_000_000,
    parameter int unsigned BAUD_RATE  = 115_200,
    parameter int unsigned FIFO_DEPTH = 32,
    parameter int unsigned I2C_RATE   = 100_000,
    parameter int unsigned GPIO_WIDTH = 32
) (
    input  logic           clk_i,
    input  logic           rst_ni,
    input  logic           req_valid_i,
    output logic           rsp_ready_o,
    output logic           rsp_error_o,

    input  apb_pkg::addr_t addr_i,
    input  logic           write_i,
    input  apb_pkg::data_t wdata_i,
    input  apb_pkg::strb_t wstrb_i,
    output apb_pkg::data_t rdata_o,

    input  logic           rxd_i,
    output logic           txd_o,

    input  logic           scl_i,
    input  logic           sda_i,
    output logic           scl_drive_low_o,
    output logic           sda_drive_low_o,

    input  logic [GPIO_WIDTH-1:0] gpio_i,
    output logic [GPIO_WIDTH-1:0] gpio_o,
    output logic [GPIO_WIDTH-1:0] gpio_oe_o
);

    apb_if apb_ctrl_bus();
    apb_if apb_peripherals_bus[apb_addr_map_pkg::NUM_SLAVES]();

    apb_master u_apb_master (
        .pclk_i             (clk_i),
        .preset_ni          (rst_ni),
        .req_valid_i        (req_valid_i),
        .rsp_ready_o        (rsp_ready_o),
        .rsp_error_o        (rsp_error_o),
        .addr_i             (addr_i),
        .write_i            (write_i),
        .wdata_i            (wdata_i),
        .wstrb_i            (wstrb_i),
        .rdata_o            (rdata_o),
        .req                (apb_ctrl_bus)
    );

    apb_interconnect #(
        .SLOT_OFFSET_WIDTH  (apb_addr_map_pkg::SLOT_OFFSET_WIDTH),
        .NUM_SLAVES         (apb_addr_map_pkg::NUM_SLAVES),
        .BASE_ADDR          (apb_addr_map_pkg::PERIPH_BASE_ADDR)
    ) u_apb_interconnect (
        .cpl                (apb_ctrl_bus),
        .req                (apb_peripherals_bus)
    );

    apb_uart #(
        .CLOCK_RATE         (CLOCK_RATE),
        .BAUD_RATE          (BAUD_RATE),
        .FIFO_DEPTH         (FIFO_DEPTH)
    ) u_apb_uart0 (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .rxd_i              (rxd_i),
        .txd_o              (txd_o),
        .cpl                (apb_peripherals_bus[apb_addr_map_pkg::UART0_IDX])
    );

    apb_timer u_apb_timer (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .irq_o              (),
        .cpl                (apb_peripherals_bus[apb_addr_map_pkg::TIMER0_IDX])
    );

    apb_i2c #(
        .CLOCK_RATE         (CLOCK_RATE),
        .I2C_RATE           (I2C_RATE)
    ) u_apb_i2c (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .scl_i              (scl_i),
        .sda_i              (sda_i),
        .scl_drive_low_o    (scl_drive_low_o),
        .sda_drive_low_o    (sda_drive_low_o),
        .irq_o              (),
        .cpl                (apb_peripherals_bus[apb_addr_map_pkg::I2C0_IDX])
    );

    apb_gpio #(
        .WIDTH              (GPIO_WIDTH)
    ) u_apb_gpio (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .gpio_i             (gpio_i),
        .gpio_o             (gpio_o),
        .gpio_oe_o          (gpio_oe_o),
        .irq_o              (),
        .cpl                (apb_peripherals_bus[apb_addr_map_pkg::GPIO_IDX])
    );

endmodule
