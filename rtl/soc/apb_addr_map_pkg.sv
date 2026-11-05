//-----------------------------------------------------------------------------
//  Packages : apb_addr_map_pkg, uart_reg_pkg, timer_reg_pkg, i2c_reg_pkg, gpio_reg_pkg
//
//  Description:
//     Shared peripherals address map and register offsets.
//     NUM_SLAVES and PERIPH_BASE_ADDR must match the enabled peripheral branches.
//     To add a peripheral: allocate a unique index, increase NUM_SLAVES,
//     and add its aligned, non-overlapping BASE_ADDR entry.
//
//-----------------------------------------------------------------------------

package apb_addr_map_pkg;
    localparam int unsigned SLOT_OFFSET_WIDTH = 12;

    localparam int unsigned UART0_IDX  = 0;
    localparam int unsigned TIMER0_IDX = 1;
    localparam int unsigned I2C0_IDX   = 2;
    localparam int unsigned GPIO_IDX   = 3;
    localparam int unsigned NUM_SLAVES = 4;

    localparam apb_pkg::addr_t PERIPH_BASE_ADDR [NUM_SLAVES] = '{
        UART0_IDX:  32'h8000_0000,
        TIMER0_IDX: 32'h8000_1000,
        I2C0_IDX:   32'h8000_2000,
        GPIO_IDX:   32'h8000_3000
    };

endpackage

package uart_reg_pkg;

    localparam logic [11:0] TX_OFFSET     = 12'h000;
    localparam logic [11:0] RX_OFFSET     = 12'h004;
    localparam logic [11:0] STATUS_OFFSET = 12'h008;

endpackage

package timer_reg_pkg;

    localparam logic [11:0] CTRL_OFFSET      = 12'h000;
    localparam logic [11:0] PRESCALER_OFFSET = 12'h004;
    localparam logic [11:0] RELOAD_OFFSET    = 12'h008;
    localparam logic [11:0] VALUE_OFFSET     = 12'h00c;
    localparam logic [11:0] STATUS_OFFSET    = 12'h010;
    localparam logic [11:0] COMMAND_OFFSET   = 12'h014;

endpackage

package i2c_reg_pkg;

    localparam logic [11:0] ADDRESS_OFFSET    = 12'h000;
    localparam logic [11:0] TXDATA_OFFSET     = 12'h004;
    localparam logic [11:0] RXDATA_OFFSET     = 12'h008;
    localparam logic [11:0] COMMAND_OFFSET    = 12'h00c;
    localparam logic [11:0] STATUS_OFFSET     = 12'h010;
    localparam logic [11:0] IRQ_ENABLE_OFFSET = 12'h014;

endpackage

package gpio_reg_pkg;

    localparam logic [11:0] INPUT_OFFSET           = 12'h000;
    localparam logic [11:0] OUTPUT_OFFSET          = 12'h004;
    localparam logic [11:0] OUTPUT_ENABLE_OFFSET   = 12'h008;
    localparam logic [11:0] IRQ_RISE_ENABLE_OFFSET = 12'h00c;
    localparam logic [11:0] IRQ_FALL_ENABLE_OFFSET = 12'h010;
    localparam logic [11:0] IRQ_STATUS_OFFSET      = 12'h014;

endpackage
