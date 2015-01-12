// This file is automatically generated.

#include <avr/io.h>
#include <stdbool.h>

static void clock();

static void stream_1(unsigned int input_0);

static void stream_2(bool input_0);

static void stream_3(unsigned int input_0);

static void stream_4(char * input_0);

static void clock() {
  static unsigned int temp0 = 0U;
  temp0++;
  stream_1(temp0);
  stream_3(temp0);
}

static void stream_1(unsigned int input_0) {
  bool temp1;
  temp1 = (input_0) % 2 == 0;
  stream_2(temp1);
}

static void stream_2(bool input_0) {
  if (input_0) {
    PORTB |= (1 << PB5);
  } else {
    PORTB &= ~(1 << PB5);
  }
}

static void stream_3(unsigned int input_0) {
  char * temp2;
  char temp3[] = "hello\r\n";
  temp2 = temp3;
  stream_4(temp2);
}

static void stream_4(char * input_0) {
  while (*input_0 != 0) {
    while ((UCSR0A & (1 << UDRE0)) == 0) {
    }
    UDR0 = *input_0;
    input_0++;
  }
}

int main(void) {
  TCCR1B = (1 << CS12) | (1 << CS10);
  DDRB |= (1 << PB5);
  #define F_CPU 16000000UL
  #define BAUD 9600
  #include <util/setbaud.h>
  UBRR0H = UBRRH_VALUE;
  UBRR0L = UBRRL_VALUE;
  #if USE_2X
    UCSR0A |= (1 << U2X0);
  #else
    UCSR0A &= ~((1 << U2X0));
  #endif
  UCSR0C = (1 << UCSZ01) |(1 << UCSZ00);
  UCSR0B = (1 << RXEN0) | (1 << TXEN0);
  while (1) {
    if (TCNT1 >= 10000) {
      TCNT1 = 0;
      clock();
    }
  }
  return 0;
}
