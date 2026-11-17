#include "dht22.h"

#include "soc.h"

#define REG32(offset) (*(volatile uint32_t *)((uintptr_t)DHT22_BASE + (offset)))

#define DHT22_COMMAND     REG32(0x00u)
#define DHT22_STATUS      REG32(0x04u)
#define DHT22_TEMPERATURE REG32(0x08u)
#define DHT22_HUMIDITY    REG32(0x0cu)

#define STATUS_BUSY       (1u << 0)
#define STATUS_VALID      (1u << 1)
#define STATUS_CHECKSUM   (1u << 2)
#define STATUS_TIMEOUT    (1u << 3)

void dht22_start(void)
{
    if ((DHT22_STATUS & STATUS_BUSY) == 0u) DHT22_COMMAND = 1u;
}

dht22_result_t dht22_result(void)
{
    const uint32_t status = DHT22_STATUS;
    if ((status & STATUS_BUSY) != 0u) return DHT22_BUSY;
    if ((status & STATUS_VALID) != 0u) return DHT22_OK;
    if ((status & STATUS_CHECKSUM) != 0u) return DHT22_CHECKSUM_ERROR;
    return DHT22_TIMEOUT;
}

void dht22_read(dht22_sample_t *sample)
{
    if (sample == 0) return;
    sample->temperature_tenths = (int16_t)DHT22_TEMPERATURE;
    sample->humidity_tenths = DHT22_HUMIDITY & 0xffffu;
}
