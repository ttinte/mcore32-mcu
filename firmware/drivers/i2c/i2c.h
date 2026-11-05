#ifndef I2C_H
#define I2C_H

#include <stdint.h>

typedef enum {
    I2C_OK = 0,
    I2C_NACK,
    I2C_ARBITRATION_LOST,
    I2C_TIMEOUT,
    I2C_INVALID_ARGUMENT
} i2c_result_t;

/* Polling, one data byte per START/address/data/STOP. timebase_init() first. */
void i2c_init(void);
i2c_result_t i2c_write_byte(uint8_t address, uint8_t value);
i2c_result_t i2c_read_byte(uint8_t address, uint8_t *value);

#endif
