#ifndef SOC_H
#define SOC_H

#include <stdint.h>

// These values describe the RTL; changing them does not configure hardware.
#define RAM_BASE        0x00000000u
#define RAM_END         0x00008000u
#define RAM_SIZE_BYTES  (RAM_END - RAM_BASE)
#define UART_BASE       0x80000000u
#define TIMER_BASE      0x80001000u
#define I2C_BASE        0x80002000u
#define GPIO_BASE       0x80003000u
#define CLOCK_HZ        70000000u
#define UART_BAUD_RATE  115200u

#endif
