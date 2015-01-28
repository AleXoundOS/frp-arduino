// This file is automatically generated.

#include <avr/io.h>
#include <stdbool.h>

struct list {
    uint8_t size;
    void* values;
};

struct tuple2 {
    void* value0;
    void* value1;
};

static void input_timer();

static void stream_1(uint8_t arg, void* value);

static void stream_6(uint8_t arg, void* value);

static void stream_2(uint8_t arg, void* value);

static void stream_7(uint8_t arg, void* value);

static void stream_3(uint8_t arg, void* value);

static void stream_8(uint8_t arg, void* value);

static void stream_4(uint8_t arg, void* value);

static void stream_5(uint8_t arg, void* value);

static void input_timer() {
  uint16_t temp0;
  temp0 = TCNT1;
  TCNT1 = 0;
  stream_1(0, (void*)(&temp0));
  stream_6(0, (void*)(&temp0));
}

static void stream_1(uint8_t arg, void* value) {
  static uint16_t input_1 = 0;
  uint16_t temp1;
  static uint16_t input_0;
  switch (arg) {
    case 0:
      input_0 = *((uint16_t*)value);
      break;
  }
  if (input_1 > 10000) {
    temp1 = input_1 - 10000 + input_0;
  } else {
    temp1 = input_1 + input_0;
  }
  input_1 = temp1;
  stream_2(0, (void*)(&input_1));
}

static void stream_6(uint8_t arg, void* value) {
  struct list temp2;
  uint8_t temp3[7];
  uint8_t temp4[20];
  struct list temp5;
  struct list temp6;
  uint8_t temp7[2];
  static uint16_t input_0;
  switch (arg) {
    case 0:
      input_0 = *((uint16_t*)value);
      break;
  }
  temp3[0] = 100;
  temp3[1] = 101;
  temp3[2] = 108;
  temp3[3] = 116;
  temp3[4] = 97;
  temp3[5] = 58;
  temp3[6] = 32;
  temp2.size = 7;
  temp2.values = (void*)temp3;
  snprintf(temp4, 20, "%d", input_0);
  temp5.size = strlen(temp4);
  temp5.values = temp4;
  temp7[0] = 13;
  temp7[1] = 10;
  temp6.size = 2;
  temp6.values = (void*)temp7;
  stream_7(0, (void*)(&temp2));
  stream_7(0, (void*)(&temp5));
  stream_7(0, (void*)(&temp6));
}

static void stream_2(uint8_t arg, void* value) {
  bool temp8;
  static uint16_t input_0;
  switch (arg) {
    case 0:
      input_0 = *((uint16_t*)value);
      break;
  }
  temp8 = false;
  if (input_0 > 10000) {
    temp8 = true;
  }
  if (temp8) {
    stream_3(0, (void*)(&input_0));
  }
}

static void stream_7(uint8_t arg, void* value) {
  uint8_t temp9;
  static struct list input_0;
  switch (arg) {
    case 0:
      input_0 = *((struct list*)value);
      break;
  }
  for (temp9 = 0; temp9 < input_0.size; temp9++) {
    stream_8(0, (void*)(&((uint8_t*)input_0.values)[temp9]));
  }
}

static void stream_3(uint8_t arg, void* value) {
  static uint16_t input_1 = 0;
  static uint16_t input_0;
  switch (arg) {
    case 0:
      input_0 = *((uint16_t*)value);
      break;
  }
  input_1 = input_1 + 1;
  stream_4(0, (void*)(&input_1));
}

static void stream_8(uint8_t arg, void* value) {
  static uint8_t input_0;
  switch (arg) {
    case 0:
      input_0 = *((uint8_t*)value);
      break;
  }
  while ((UCSR0A & (1 << UDRE0)) == 0) {
  }
  UDR0 = input_0;
}

static void stream_4(uint8_t arg, void* value) {
  bool temp10;
  static uint16_t input_0;
  switch (arg) {
    case 0:
      input_0 = *((uint16_t*)value);
      break;
  }
  temp10 = (input_0) % 2 == 0;
  stream_5(0, (void*)(&temp10));
}

static void stream_5(uint8_t arg, void* value) {
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

int main(void) {
  TCCR1B |= (1 << CS12);
  TCCR1B |= (1 << CS10);
  DDRB |= (1 << PB5);
  UBRR0H = 0;
  UBRR0L = 103;
  UCSR0C |= (1 << UCSZ01);
  UCSR0C |= (1 << UCSZ00);
  UCSR0B |= (1 << RXEN0);
  UCSR0B |= (1 << TXEN0);
  while (1) {
    input_timer();
  }
  return 0;
}
