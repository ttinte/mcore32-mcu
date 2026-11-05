#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

uint32_t gpio_read(void);
uint32_t gpio_read_output(void);
uint32_t gpio_read_output_enable(void);

void gpio_write(uint32_t value);
void gpio_write_masked(uint32_t mask, uint32_t value);
void gpio_set_output_enable(uint32_t mask);

#endif
