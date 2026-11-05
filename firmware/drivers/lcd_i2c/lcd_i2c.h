#ifndef LCD_I2C_H
#define LCD_I2C_H

#include <stdint.h>
#include "i2c/i2c.h"

/* HD44780 backpack mapping: P0=RS, P1=RW, P2=E, P3=backlight,
 * P4..P7=D4..D7. RW is always zero. Other backpack mappings need changes. */
typedef struct {
    uint8_t address;
    uint8_t backlight;
} lcd_i2c_t;

/* address=0 probes read-only at 0x27 and 0x3f; otherwise use the supplied
 * seven-bit address. This driver writes exactly 16 columns on either row. */
i2c_result_t lcd_i2c_init(lcd_i2c_t *lcd, uint8_t address);
i2c_result_t lcd_i2c_line(lcd_i2c_t *lcd, uint32_t row, const char *text);
i2c_result_t lcd_i2c_backlight(lcd_i2c_t *lcd, uint32_t enabled);

#endif
