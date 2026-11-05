#include "gpio.h"
#include "soc.h"

#define REG32(base, offset) \
    (*(volatile uint32_t *)((uintptr_t)(base) + (uintptr_t)(offset)))

#define GPIO_INPUT          REG32(GPIO_BASE, 0x00u)
#define GPIO_OUTPUT         REG32(GPIO_BASE, 0x04u)
#define GPIO_OUTPUT_ENABLE  REG32(GPIO_BASE, 0x08u)

uint32_t gpio_read(void)
{
    return GPIO_INPUT;
}

uint32_t gpio_read_output(void)
{
    return GPIO_OUTPUT;
}

uint32_t gpio_read_output_enable(void)
{
    return GPIO_OUTPUT_ENABLE;
}

void gpio_write(uint32_t value)
{
    GPIO_OUTPUT = value;
}

void gpio_write_masked(uint32_t mask, uint32_t value)
{
    GPIO_OUTPUT = (GPIO_OUTPUT & ~mask) | (value & mask);
}

void gpio_set_output_enable(uint32_t mask)
{
    GPIO_OUTPUT_ENABLE = mask;
}
