#ifndef EBAZ4205_H
#define EBAZ4205_H

/* GPIO bit mapping in test/ebaz_zjb05.sv. Carrier LEDs are active-high. */
#define EBAZ_KEY1       (1u << 0)
#define EBAZ_KEY2       (1u << 1)
#define EBAZ_KEY3       (1u << 2)
#define EBAZ_KEY4       (1u << 3)
#define EBAZ_KEY5       (1u << 4)
#define EBAZ_KEY_MASK   0x1fu
#define EBAZ_PIR        (1u << 5)
#define EBAZ_LED_MOTION (1u << 8)  /* E19 */
#define EBAZ_LED_ARMED  (1u << 9)  /* K17 */
#define EBAZ_LED_BUZZER (1u << 10) /* H18: sound enabled, not beep activity */
#define EBAZ_BUZZER     (1u << 11) /* Gate the PL 2 kHz tone on carrier D18 */
#define EBAZ_LED_MASK   (EBAZ_LED_MOTION | EBAZ_LED_ARMED | EBAZ_LED_BUZZER)

#endif
