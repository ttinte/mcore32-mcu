#ifndef DHT22_H
#define DHT22_H

#include <stdint.h>

typedef enum {
    DHT22_BUSY = 0,
    DHT22_OK,
    DHT22_CHECKSUM_ERROR,
    DHT22_TIMEOUT
} dht22_result_t;

typedef struct {
    int32_t temperature_tenths;
    uint32_t humidity_tenths;
} dht22_sample_t;

/* Starts an asynchronous sensor transaction.  Poll dht22_result() until it
 * is no longer DHT22_BUSY, then read the most recent sample on DHT22_OK. */
void dht22_start(void);
dht22_result_t dht22_result(void);
void dht22_read(dht22_sample_t *sample);

#endif
