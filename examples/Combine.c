// This file is automatically generated.

#include <avr/io.h>
#include <stdbool.h>

static void clock();

static void input_pin12();

static void stream_1(unsigned int input_0);

static void stream_2(bool input_0);

static void stream_3(int arg, void* value);

static void stream_4(bool input_0);

static void stream_5(bool input_0);

static void stream_6(int arg, void* value);

static void stream_7(bool input_0);

static void clock() {
  static unsigned int temp0 = 0U;
  temp0++;
  stream_1(temp0);
}

static void input_pin12() {
  bool temp1;
  temp1 = (PINB & (1 << PB4)) == 0U;
  stream_2(temp1);
  stream_3(0, (void*)(&temp1));
  stream_6(0, (void*)(&temp1));
}

static void stream_1(unsigned int input_0) {
  bool temp2;
  temp2 = (input_0) % 2 == 0;
  stream_3(1, (void*)(&temp2));
  stream_5(temp2);
}

static void stream_2(bool input_0) {
  if (input_0) {
    PORTB |= (1 << PB5);
  } else {
    PORTB &= ~(1 << PB5);
  }
}

static void stream_3(int arg, void* value) {
  static bool input_0;
  static bool input_1;
  switch (arg) {
    case 0:
      input_0 = *((bool*)value);
      break;
    case 1:
      input_1 = *((bool*)value);
      break;
  }
  bool temp3;
  bool temp4;
  if (input_0) {
    temp4 = input_1;
  } else {
    temp4 = false;
  }
  temp3 = temp4;
  stream_4(temp3);
}

static void stream_4(bool input_0) {
  if (input_0) {
    PORTB |= (1 << PB3);
  } else {
    PORTB &= ~(1 << PB3);
  }
}

static void stream_5(bool input_0) {
  bool temp5;
  temp5 = !(input_0);
  stream_6(1, (void*)(&temp5));
}

static void stream_6(int arg, void* value) {
  static bool input_0;
  static bool input_1;
  switch (arg) {
    case 0:
      input_0 = *((bool*)value);
      break;
    case 1:
      input_1 = *((bool*)value);
      break;
  }
  bool temp6;
  bool temp7;
  if (input_0) {
    temp7 = input_1;
  } else {
    temp7 = false;
  }
  temp6 = temp7;
  stream_7(temp6);
}

static void stream_7(bool input_0) {
  if (input_0) {
    PORTB |= (1 << PB2);
  } else {
    PORTB &= ~(1 << PB2);
  }
}

int main(void) {
  TCCR1B = (1 << CS12) | (1 << CS10);
  DDRB &= ~(1 << PB4);
  PORTB |= (1 << PB4);
  DDRB |= (1 << PB5);
  DDRB |= (1 << PB3);
  DDRB |= (1 << PB2);
  while (1) {
    if (TCNT1 >= 10000) {
      TCNT1 = 0;
      clock();
    }
    input_pin12();
  }
  return 0;
}
