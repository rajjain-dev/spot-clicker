/*
  Spot Clicker: bare-board USB check for the plain Seeed XIAO nRF52840.
  Board package: Seeed nRF52 Boards 1.1.13 (non-mbed).
  Target: Seeeduino:nrf52:xiaonRF52840

  Keep the battery, mechanical switch, and motor disconnected.
  Expected result: the user LED flashes red for half a second, then stays
  off for half a second. The green and blue user LEDs remain off.
  This is a diagnostic sketch, not the Spot Clicker Bluetooth firmware.
*/

#include <Adafruit_TinyUSB.h>

void setup() {
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);

  // The user RGB LED is active-low: HIGH turns each channel off.
  digitalWrite(LED_RED, HIGH);
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_BLUE, HIGH);
}

void loop() {
  digitalWrite(LED_RED, LOW);
  delay(500);
  digitalWrite(LED_RED, HIGH);
  delay(500);
}
