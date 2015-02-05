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

static void input_a0();

static void input_timer();

static void stream_1(uint8_t arg, void* value);

static void stream_2(uint8_t arg, void* value);

static void stream_3(uint8_t arg, void* value);

static void stream_4(uint8_t arg, void* value);

static void stream_5(uint8_t arg, void* value);

static void stream_7(uint8_t arg, void* value);

static void stream_6(uint8_t arg, void* value);

static void stream_8(uint8_t arg, void* value);

static void input_a0() {
  uint8_t temp0;
  uint8_t temp1;
  uint16_t temp2;
  ADMUX &= ~(1 << MUX3);
  ADMUX &= ~(1 << MUX2);
  ADMUX &= ~(1 << MUX1);
  ADMUX &= ~(1 << MUX0);
  ADCSRA |= (1 << ADSC);
  while ((ADCSRA & (1 << ADSC)) != 0) {
  }
  temp0 = ADCL;
  temp1 = ADCH;
  temp2 = temp0 | (temp1 << 8);
  stream_1(1, (void*)(&temp2));
}

static void input_timer() {
  uint16_t temp3;
  temp3 = TCNT1;
  TCNT1 = 0;
  stream_1(0, (void*)(&temp3));
}

static void stream_1(uint8_t arg, void* value) {
  static uint16_t input_0;
  static uint16_t input_1;
  uint16_t temp4;
  uint16_t temp5;
  struct tuple2 temp6;
  switch (arg) {
    case 0:
      input_0 = *((uint16_t*)value);
      break;
    case 1:
      input_1 = *((uint16_t*)value);
      break;
  }
  temp4 = input_0;
  temp5 = input_1;
  temp6.value0 = (void*)&temp4;
  temp6.value1 = (void*)&temp5;
  stream_2(0, (void*)(&temp6));
}

static void stream_2(uint8_t arg, void* value) {
  struct tuple2 input_0 = *((struct tuple2*)value);
  static uint16_t temp7 = 0;
  static uint16_t temp8 = 0;
  static struct tuple2 input_1 = { .value0 = (void*)&temp7, .value1 = (void*)&temp8 };
  uint16_t temp9;
  uint16_t temp10;
  struct tuple2 temp11;
  uint16_t temp12;
  uint16_t temp13;
  struct tuple2 temp14;
  struct tuple2 temp15;
  temp9 = 0;
  temp10 = *((uint16_t*)input_0.value1);
  temp11.value0 = (void*)&temp9;
  temp11.value1 = (void*)&temp10;
  temp12 = (*((uint16_t*)input_0.value0) + *((uint16_t*)input_1.value0));
  temp13 = *((uint16_t*)input_0.value1);
  temp14.value0 = (void*)&temp12;
  temp14.value1 = (void*)&temp13;
  if ((*((uint16_t*)input_1.value0) > (1000 + (*((uint16_t*)input_0.value1) * 20)))) {
    temp15 = temp11;
  } else {
    temp15 = temp14;
  }
  *((uint16_t*)input_1.value0) = *((uint16_t*)temp15.value0);
  *((uint16_t*)input_1.value1) = *((uint16_t*)temp15.value1);
  stream_3(0, (void*)(&input_1));
}

static void stream_3(uint8_t arg, void* value) {
  struct tuple2 input_0 = *((struct tuple2*)value);
  if (*((uint16_t*)input_0.value0) == 0) {
    stream_4(0, (void*)(&input_0));
  }
}

static void stream_4(uint8_t arg, void* value) {
  struct tuple2 input_0 = *((struct tuple2*)value);
  static bool temp16 = false;
  static bool temp17 = true;
  static struct tuple2 input_1 = { .value0 = (void*)&temp16, .value1 = (void*)&temp17 };
  bool temp18;
  bool temp19;
  struct tuple2 temp20;
  temp18 = *((bool*)input_1.value1);
  temp19 = *((bool*)input_1.value0);
  temp20.value0 = (void*)&temp18;
  temp20.value1 = (void*)&temp19;
  *((bool*)input_1.value0) = *((bool*)temp20.value0);
  *((bool*)input_1.value1) = *((bool*)temp20.value1);
  stream_5(0, (void*)(&input_1));
  stream_7(0, (void*)(&input_1));
}

static void stream_5(uint8_t arg, void* value) {
  struct tuple2 input_0 = *((struct tuple2*)value);
  stream_6(0, (void*)(&*((bool*)input_0.value0)));
}

static void stream_7(uint8_t arg, void* value) {
  struct tuple2 input_0 = *((struct tuple2*)value);
  stream_8(0, (void*)(&*((bool*)input_0.value1)));
}

static void stream_6(uint8_t arg, void* value) {
  bool input_0 = *((bool*)value);
  if (input_0) {
    PORTB |= (1 << PB3);
  } else {
    PORTB &= ~(1 << PB3);
  }
}

static void stream_8(uint8_t arg, void* value) {
  bool input_0 = *((bool*)value);
  if (input_0) {
    PORTB |= (1 << PB4);
  } else {
    PORTB &= ~(1 << PB4);
  }
}

int main(void) {
  ADCSRA |= (1 << ADEN);
  ADMUX |= (1 << REFS0);
  ADCSRA |= (1 << ADPS2);
  ADCSRA |= (1 << ADPS1);
  ADCSRA |= (1 << ADPS0);
  TCCR1B |= (1 << CS12);
  TCCR1B |= (1 << CS10);
  DDRB |= (1 << PB3);
  DDRB |= (1 << PB4);
  while (1) {
    input_a0();
    input_timer();
  }
  return 0;
}