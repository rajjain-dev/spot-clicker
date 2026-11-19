/*
  Spot Clicker: USB-powered input check for the plain Seeed XIAO nRF52840.
  Board package: Seeed nRF52 Boards 1.1.13 (non-mbed).
  Target: Seeeduino:nrf52:xiaonRF52840

  With USB unplugged, connect one continuity-verified DIP-switch channel
  between D1 and GND. Leave its other channel, battery, and motor disconnected.
  Use the internal pull-up; no external input resistor is required.

  Expected result:
    DIP OFF / open contact: red user LED off.
    DIP ON / closed contact: red user LED on.

  This is a maintained-input diagnostic, not gesture or Bluetooth firmware.
*/

#include <Adafruit_TinyUSB.h>

constexpr uint8_t SWITCH_PIN = D1;
constexpr uint32_t DEBOUNCE_MS = 25;

bool rawClosed = false;
bool stableClosed = false;
uint32_t rawChangedAt = 0;

void showSwitchState() {
  // The user RGB LED is active-low.
  digitalWrite(LED_RED, stableClosed ? LOW : HIGH);
  if (Serial) {
    Serial.println(stableClosed ? "Switch ON: D1 connected to GND"
                                : "Switch OFF: D1 contact open");
  }
}

void setup() {
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  digitalWrite(LED_RED, HIGH);
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_BLUE, HIGH);

  pinMode(SWITCH_PIN, INPUT_PULLUP);
  rawClosed = digitalRead(SWITCH_PIN) == LOW;
  stableClosed = rawClosed;
  rawChangedAt = millis();

  Serial.begin(115200);
  // Never wait for a serial monitor: the diagnostic must start on its own.
  showSwitchState();
}

void loop() {
  const uint32_t now = millis();
  const bool closed = digitalRead(SWITCH_PIN) == LOW;
  if (closed != rawClosed) {
    rawClosed = closed;
    rawChangedAt = now;
  }
  if (rawClosed != stableClosed && now - rawChangedAt >= DEBOUNCE_MS) {
    stableClosed = rawClosed;
    showSwitchState();
  }
  delay(1);
}
