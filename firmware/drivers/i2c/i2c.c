#include "i2c.h"

#include "soc.h"
#include "timer/timer.h"

#define REG32(offset) (*(volatile uint32_t *)((uintptr_t)I2C_BASE + (offset)))
#define I2C_ADDRESS    REG32(0x00u)
#define I2C_TXDATA     REG32(0x04u)
#define I2C_RXDATA     REG32(0x08u)
#define I2C_COMMAND    REG32(0x0cu)
#define I2C_STATUS     REG32(0x10u)
#define I2C_IRQ_ENABLE REG32(0x14u)

#define STATUS_BUSY    (1u << 0)
#define STATUS_DONE    (1u << 1)
#define STATUS_NACK    (1u << 2)
#define STATUS_ARB     (1u << 3)
#define STATUS_CLEAR  (STATUS_DONE | STATUS_NACK | STATUS_ARB)
#define TRANSFER_TIMEOUT_US 20000u

void i2c_init(void)
{
    I2C_IRQ_ENABLE = 0u;
    I2C_STATUS = STATUS_CLEAR;
}

static i2c_result_t transfer(uint8_t address, uint32_t read,
                             uint8_t transmit, uint8_t *received)
{
    uint32_t status;
    uint32_t start;

    if (address > 0x7fu || (read != 0u && received == 0)) {
        return I2C_INVALID_ARGUMENT;
    }

    start = timebase_us();
    while ((I2C_STATUS & STATUS_BUSY) != 0u) {
        if ((uint32_t)(timebase_us() - start) >= TRANSFER_TIMEOUT_US) {
            return I2C_TIMEOUT;
        }
    }

    I2C_STATUS = STATUS_CLEAR;
    I2C_ADDRESS = address;
    if (read == 0u) {
        I2C_TXDATA = transmit;
    }
    I2C_COMMAND = 1u | (read << 1);

    start = timebase_us();
    do {
        status = I2C_STATUS;
        if ((uint32_t)(timebase_us() - start) >= TRANSFER_TIMEOUT_US) {
            /* Leave the peripheral alone if a slave is holding the bus low.
             * A subsequent call also times out instead of writing while busy. */
            return I2C_TIMEOUT;
        }
    } while ((status & STATUS_DONE) == 0u);

    I2C_STATUS = STATUS_CLEAR;
    if ((status & STATUS_ARB) != 0u) {
        return I2C_ARBITRATION_LOST;
    }
    if ((status & STATUS_NACK) != 0u) {
        return I2C_NACK;
    }
    if (read != 0u) {
        *received = (uint8_t)I2C_RXDATA;
    }
    return I2C_OK;
}

i2c_result_t i2c_write_byte(uint8_t address, uint8_t value)
{
    return transfer(address, 0u, value, 0);
}

i2c_result_t i2c_read_byte(uint8_t address, uint8_t *value)
{
    return transfer(address, 1u, 0u, value);
}
