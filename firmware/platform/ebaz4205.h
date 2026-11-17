#ifndef EBAZ4205_H
#define EBAZ4205_H

/* GPIO mapping in ebaz4205_top.sv.  Carrier LEDs are active-high. */
#define EBAZ_KEY_BUZZER (1u << 0)  /* KEY5, active-low */
#define EBAZ_LED_BUZZER (1u << 9)  /* H18: sound enabled, not beep activity */
#define EBAZ_BUZZER     (1u << 11) /* Gate the PL 2 kHz tone on carrier D18 */
#define EBAZ_LED_MASK   EBAZ_LED_BUZZER

#endif
