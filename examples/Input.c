// This file is automatically generated.

#include <avr/io.h>
#include <util/delay_basic.h>
#include <stdbool.h>

struct list {
    uint8_t size;
    void* values;
};

struct tuple2 {
    void* value0;
    void* value1;
};

struct tuple6 {
    void* value0;
    void* value1;
    void* value2;
    void* value3;
    void* value4;
    void* value5;
};

static void input_pin12();

static void input_timer();

static void stream_1(uint8_t arg, void* value);

static void stream_2(uint8_t arg, void* value);

static void stream_3(uint8_t arg, void* value);

static void stream_4(uint8_t arg, void* value);

static void stream_5(uint8_t arg, void* value);

static void stream_6(uint8_t arg, void* value);

static void input_pin12() {
  bool temp0;
  temp0 = (PINB & (1 << PB4)) == 0U;
  stream_1(0, (void*)(&temp0));
}

static void input_timer() {
  uint16_t temp1;
  temp1 = TCNT1;
  TCNT1 = 0;
  stream_2(0, (void*)(&temp1));
}

static void stream_1(uint8_t arg, void* value) {
  static bool input_0;
  switch (arg) {
    case 0:
      input_0 = *((bool*)value);
      break;
  }
  if (input_0) {
    PORTB |= (1 << PB5);
  } else {
    PORTB &= ~(1 << PB5);
  }
}

static void stream_2(uint8_t arg, void* value) {
  static uint16_t input_1 = 0;
  uint16_t temp2;
  static uint16_t input_0;
  switch (arg) {
    case 0:
      input_0 = *((uint16_t*)value);
      break;
  }
  if ((input_1 > 10000)) {
    temp2 = ((input_1 - 10000) + input_0);
  } else {
    temp2 = (input_1 + input_0);
  }
  input_1 = temp2;
  stream_3(0, (void*)(&input_1));
}

static void stream_3(uint8_t arg, void* value) {
  static uint16_t input_0;
  switch (arg) {
    case 0:
      input_0 = *((uint16_t*)value);
      break;
  }
  if ((input_0 > 10000)) {
    stream_4(0, (void*)(&input_0));
  }
}

static void stream_4(uint8_t arg, void* value) {
  static uint16_t input_1 = 0;
  static uint16_t input_0;
  switch (arg) {
    case 0:
      input_0 = *((uint16_t*)value);
      break;
  }
  input_1 = (input_1 + 1);
  stream_5(0, (void*)(&input_1));
}

static void stream_5(uint8_t arg, void* value) {
  bool temp3;
  static uint16_t input_0;
  switch (arg) {
    case 0:
      input_0 = *((uint16_t*)value);
      break;
  }
  temp3 = (input_0) % 2 == 0;
  stream_6(0, (void*)(&temp3));
}

static void stream_6(uint8_t arg, void* value) {
  static bool input_0;
  switch (arg) {
    case 0:
      input_0 = *((bool*)value);
      break;
  }
  if (input_0) {
    PORTB |= (1 << PB3);
  } else {
    PORTB &= ~(1 << PB3);
  }
}

int main(void) {
  DDRB &= ~(1 << PB4);
  PORTB |= (1 << PB4);
  TCCR1B |= (1 << CS12);
  TCCR1B |= (1 << CS10);
  DDRB |= (1 << PB5);
  DDRB |= (1 << PB3);
  while (1) {
    input_pin12();
    input_timer();
  }
  return 0;
}
