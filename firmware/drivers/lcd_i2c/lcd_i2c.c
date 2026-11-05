#include "lcd_i2c.h"

#include "timer/timer.h"

#define LCD_RS        0x01u
#define LCD_ENABLE    0x04u
#define LCD_BACKLIGHT 0x08u

static i2c_result_t nibble(lcd_i2c_t *lcd, uint8_t value, uint8_t rs)
{
    const uint8_t port = (uint8_t)((value & 0xf0u) | rs | lcd->backlight);
    i2c_result_t result = i2c_write_byte(lcd->address, port);
    if (result != I2C_OK) return result;
    result = i2c_write_byte(lcd->address, (uint8_t)(port | LCD_ENABLE));
    if (result != I2C_OK) return result;
    timebase_delay_us(1u);
    return i2c_write_byte(lcd->address, port);
}

static i2c_result_t send(lcd_i2c_t *lcd, uint8_t value, uint8_t rs)
{
    i2c_result_t result = nibble(lcd, value, rs);
    if (result != I2C_OK) return result;
    result = nibble(lcd, (uint8_t)(value << 4), rs);
    if (result == I2C_OK) {
        timebase_delay_us(rs == 0u && (value == 1u || value == 2u)
                          ? 2000u : 50u);
    }
    return result;
}

i2c_result_t lcd_i2c_init(lcd_i2c_t *lcd, uint8_t address)
{
    uint8_t pins;
    i2c_result_t result;
    if (lcd == 0 || address > 0x7fu) return I2C_INVALID_ARGUMENT;

    /* Read probes do not change a PCF8574's output latch. */
    lcd->address = address == 0u ? 0x27u : address;
    lcd->backlight = LCD_BACKLIGHT;
    result = i2c_read_byte(lcd->address, &pins);
    if (address == 0u && result == I2C_NACK) {
        lcd->address = 0x3fu;
        result = i2c_read_byte(lcd->address, &pins);
    }
    if (result != I2C_OK) return result;

    /* HD44780 instruction reset, including recovery from an interrupted nibble. */
    timebase_delay_us(50000u);
    result = nibble(lcd, 0x30u, 0u);
    if (result != I2C_OK) return result;
    timebase_delay_us(5000u);
    result = nibble(lcd, 0x30u, 0u);
    if (result != I2C_OK) return result;
    timebase_delay_us(200u);
    result = nibble(lcd, 0x30u, 0u);
    if (result != I2C_OK) return result;
    timebase_delay_us(200u);
    result = nibble(lcd, 0x20u, 0u);
    if (result != I2C_OK) return result;
    timebase_delay_us(200u);

    result = send(lcd, 0x28u, 0u); // Four-bit, two-line, 5x8 font.
    if (result != I2C_OK) return result;
    result = send(lcd, 0x08u, 0u); // Display off during setup.
    if (result != I2C_OK) return result;
    result = send(lcd, 0x01u, 0u); // Clear DDRAM.
    if (result != I2C_OK) return result;
    result = send(lcd, 0x06u, 0u); // Increment cursor, no shift.
    if (result != I2C_OK) return result;
    return send(lcd, 0x0cu, 0u);  // Display on, cursor off.
}

i2c_result_t lcd_i2c_line(lcd_i2c_t *lcd, uint32_t row, const char *text)
{
    i2c_result_t result;
    uint32_t ended = 0u;
    if (lcd == 0 || text == 0 || row > 1u) return I2C_INVALID_ARGUMENT;
    result = send(lcd, row == 0u ? 0x80u : 0xc0u, 0u);
    if (result != I2C_OK) return result;
    for (uint32_t column = 0u; column < 16u; ++column) {
        uint8_t character = ' ';
        if (ended == 0u) {
            character = (uint8_t)*text;
            if (character == 0u) {
                ended = 1u;
                character = ' ';
            } else {
                ++text;
            }
        }
        result = send(lcd, character, LCD_RS);
        if (result != I2C_OK) return result;
    }
    return I2C_OK;
}

i2c_result_t lcd_i2c_backlight(lcd_i2c_t *lcd, uint32_t enabled)
{
    if (lcd == 0) return I2C_INVALID_ARGUMENT;
    lcd->backlight = enabled != 0u ? LCD_BACKLIGHT : 0u;
    return i2c_write_byte(lcd->address, lcd->backlight);
}
