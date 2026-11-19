/*
  Spot Clicker — plain Seeed XIAO nRF52840, Seeed nRF52 Boards 1.1.13.
  Target: Seeeduino:nrf52:xiaonRF52840 (non-mbed / Bluefruit).

  USB commands at 115200 baud (no external button required):
    1 = single / Liked, 2 = double / Want to go, 3 or h = hold / undo
    s = status, l = BLUE LED test only, m = one 10 s motor pulse, x = stop, ? = help
  Both USB and a future momentary button on D1-to-GND use emitClick().

  Current USB-only test: USB powers the XIAO; its 3V3 powers the motor driver.
  Battery and bench supply remain disconnected. D4 controls the base through 1k.
  The explicit m command permits one short pulse per boot. Automatic feedback
  vibration remains disabled; this test does not establish electrical limits.
  Phone feedback: 1 Liked, 2 Want to go, 3 error, 4 undone.
  Green patterns mean a result from the phone; red means error/uncertainty.
  USB commands bypass physical gesture timing, not Bluetooth or phone storage.
*/

#include <Adafruit_TinyUSB.h>
#include <bluefruit.h>
#include <atomic>
#include "ButtonGestures.h"

constexpr char DEVICE_NAME[] = "SpotClicker";
constexpr char SERVICE_UUID[] = "7A1C0001-5B3E-4D2A-9F10-3C5D8E2B6A01";
constexpr char CLICK_UUID[] = "7A1C0002-5B3E-4D2A-9F10-3C5D8E2B6A01";
constexpr char FEEDBACK_UUID[] = "7A1C0003-5B3E-4D2A-9F10-3C5D8E2B6A01";
constexpr uint8_t BUTTON_PIN = D1;
constexpr uint8_t MOTOR_PIN = D4;
constexpr bool MOTOR_ENABLED = false;
constexpr uint16_t USB_MOTOR_PULSE_MS = 10000;
constexpr uint32_t FEEDBACK_TIMEOUT_MS = 15000;

BLEService clickerService(SERVICE_UUID);
BLECharacteristic clickCharacteristic(CLICK_UUID);
BLECharacteristic feedbackCharacteristic(FEEDBACK_UUID);
ButtonGestures gestures;
std::atomic<uint8_t> incomingFeedback{0};

const uint16_t SAVED_PATTERN[] = {150};
const uint16_t WANT_PATTERN[] = {90, 90, 90};
const uint16_t ERROR_PATTERN[] = {60, 60, 60, 60, 60};
const uint16_t UNDONE_PATTERN[] = {450};
const uint16_t LED_TEST_PATTERN[] = {120};
const uint16_t* activePattern = nullptr;
uint8_t patternLength = 0;
uint8_t patternStep = 0;
uint8_t patternLed = LED_RED;
uint32_t patternStartedAt = 0;

bool bleReady = false;
bool previousConnected = false;
bool previousSubscribed = false;
bool serialWasOpen = false;
bool awaitingFeedback = false;
bool usbMotorPulseUsed = false;
uint8_t sequence = 0;
uint8_t pendingType = 0;
uint32_t sentAt = 0;

void setPatternOutput(bool on) {
  digitalWrite(LED_RED, HIGH);
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_BLUE, HIGH);
  if (on) digitalWrite(patternLed, LOW);
  digitalWrite(MOTOR_PIN, MOTOR_ENABLED && on && patternLed != LED_BLUE ? HIGH : LOW);
}

void playPattern(const uint16_t* steps, uint8_t length, uint8_t led) {
  activePattern = steps;
  patternLength = length;
  patternStep = 0;
  patternLed = led;
  patternStartedAt = millis();
  setPatternOutput(true);
}

void playError() {
  playPattern(ERROR_PATTERN, 5, LED_RED);
}

void updatePattern() {
  if (!activePattern || millis() - patternStartedAt < activePattern[patternStep]) return;
  patternStartedAt = millis();
  if (++patternStep >= patternLength) {
    activePattern = nullptr;
    setPatternOutput(false);
  } else {
    setPatternOutput(patternStep % 2 == 0);
  }
}

bool phoneConnected() {
  return bleReady && Bluefruit.Periph.connected() > 0;
}

bool phoneSubscribed() {
  return phoneConnected() && clickCharacteristic.notifyEnabled();
}

void printStatus() {
  if (!Serial) return;
  Serial.println("STATUS SpotClicker nRF52840 USB-motor-test v4");
  Serial.print("Uptime ms: "); Serial.println(millis());
  Serial.print("BLE initialized: "); Serial.println(bleReady ? "yes" : "no");
  Serial.print("Advertising: "); Serial.println(bleReady && Bluefruit.Advertising.isRunning() ? "yes" : "no");
  Serial.print("Phone connected: "); Serial.println(phoneConnected() ? "yes" : "no");
  Serial.print("Notifications subscribed: "); Serial.println(phoneSubscribed() ? "yes" : "no");
  Serial.print("Awaiting phone feedback: "); Serial.println(awaitingFeedback ? "yes" : "no");
  Serial.print("Automatic motor feedback enabled: "); Serial.println(MOTOR_ENABLED ? "yes" : "no");
  Serial.print("USB motor command: m = one "); Serial.print(USB_MOTOR_PULSE_MS); Serial.println(" ms pulse per boot.");
  Serial.print("USB motor pulse used: "); Serial.println(usbMotorPulseUsed ? "yes" : "no");
  Serial.println("Motor control: D4 through 1 kOhm to transistor base; motor power from XIAO 3V3.");
  Serial.print("Service UUID: "); Serial.println(SERVICE_UUID);
  Serial.print("Click UUID: "); Serial.println(CLICK_UUID);
  Serial.print("Feedback UUID: "); Serial.println(FEEDBACK_UUID);
  Serial.println("No disconnected-click queue. Wait for the phone result before another action.");
}

void printHelp() {
  if (!Serial) return;
  Serial.println("USB: 1=Liked, 2=Want to go, 3/h=undo, s=status, l=BLUE LED test, m=motor pulse, x=stop, ?=help");
  Serial.println("Green feedback comes from the phone. Red can mean an error or uncertain save.");
}

void runUSBMotorPulse() {
  if (usbMotorPulseUsed) {
    Serial.println("REJECTED MOTOR TEST: already used this boot; reset to re-arm.");
    return;
  }
  if (awaitingFeedback || activePattern) {
    Serial.println("BUSY: wait for the current action/pattern before the motor test.");
    return;
  }
  // An explicit USB command is the only trigger. No click or phone write occurs.
  // Consume it before energizing so queued characters cannot repeat the pulse.
  usbMotorPulseUsed = true;
  Serial.print("TEST MOTOR start: D4 HIGH for "); Serial.print(USB_MOTOR_PULSE_MS); Serial.println(" ms; no click sent.");
  digitalWrite(MOTOR_PIN, HIGH);
  Serial.print("Motor GPIO digital readback: "); Serial.println(digitalRead(MOTOR_PIN) == HIGH ? "HIGH" : "LOW");
  const uint32_t pulseStartedAt = millis();
  bool stopped = false;
  // Keep a fixed deadline, while allowing x or a closed USB session to stop early.
  // Discard other commands during the test so none can save a spot or retrigger it.
  while (millis() - pulseStartedAt < USB_MOTOR_PULSE_MS) {
    if (!Serial) { stopped = true; break; }
    if (Serial.available()) {
      const char command = Serial.read();
      if (command == 'x' || command == 'X') { stopped = true; break; }
    }
    delay(1);
  }
  digitalWrite(MOTOR_PIN, LOW);
  Serial.print(stopped ? "TEST MOTOR stopped early after " : "TEST MOTOR complete after ");
  Serial.print(millis() - pulseStartedAt); Serial.println(" ms; D4 commanded LOW.");
}

void feedbackWritten(uint16_t, BLECharacteristic*, uint8_t* data, uint16_t length) {
  if (length == 1 && data[0] >= 1 && data[0] <= 4) {
    // Only one action can be outstanding. Keep callbacks free of output/delays.
    incomingFeedback.store(data[0]);
  }
}

void emitClick(uint8_t type, const char* source) {
  if (awaitingFeedback) {
    if (Serial) Serial.println("BUSY: wait for feedback or inspect the phone before retrying.");
    return;
  }
  if (!phoneSubscribed()) {
    if (Serial) {
      Serial.print("REJECTED "); Serial.print(source); Serial.print(" type="); Serial.print(type);
      Serial.println(": phone not ready; nothing queued or replayed later.");
    }
    playError();
    return;
  }

  incomingFeedback.store(0);
  const uint8_t payload[] = {type, sequence};
  pendingType = type;
  awaitingFeedback = true;
  sentAt = millis();
  if (!clickCharacteristic.notify(payload, sizeof(payload))) {
    awaitingFeedback = false;
    if (Serial) Serial.println("REJECTED: Bluetooth notification could not be queued.");
    playError();
    return;
  }
  if (Serial) {
    Serial.print("SENT "); Serial.print(source); Serial.print(" type="); Serial.print(type);
    Serial.print(" sequence="); Serial.print(sequence); Serial.println("; awaiting phone result.");
  }
  ++sequence;
}

void readUSB() {
  const bool open = static_cast<bool>(Serial);
  if (open && !serialWasOpen) { printHelp(); printStatus(); }
  serialWasOpen = open;
  // Bound the work per loop so a stream of USB data cannot starve BLE/feedback.
  for (uint8_t count = 0; count < 16 && Serial.available(); ++count) {
    const char command = Serial.read();
    if (command >= '1' && command <= '3') emitClick(command - '0', "USB");
    else if (command == 'h' || command == 'H') emitClick(3, "USB");
    else if (command == 's' || command == 'S') printStatus();
    else if (command == '?') printHelp();
    else if (command == 'm' || command == 'M') runUSBMotorPulse();
    else if (command == 'x' || command == 'X') {
      digitalWrite(MOTOR_PIN, LOW);
      if (Serial) Serial.println("Motor commanded LOW.");
    }
    else if (command == 'l' || command == 'L') {
      if (!awaitingFeedback) {
        if (Serial) Serial.println("TEST BLUE LED only; no click sent and no spot saved.");
        playPattern(LED_TEST_PATTERN, 1, LED_BLUE);
      }
    }
    else if (command != '\r' && command != '\n' && command != ' ') {
      if (Serial) Serial.println("Unknown USB command; send ? for help.");
    }
  }
}

void updatePhoneState() {
  const bool connected = phoneConnected();
  const bool subscribed = phoneSubscribed();
  if (connected != previousConnected) {
    if (Serial) Serial.println(connected ? "BLE connected; waiting for notification subscription."
                                       : "BLE disconnected; advertising restarts automatically.");
    previousConnected = connected;
  }
  if (subscribed != previousSubscribed) {
    if (Serial) Serial.println(subscribed ? "READY: phone subscribed to click events."
                                        : "NOT READY: click notifications are not subscribed.");
    previousSubscribed = subscribed;
  }
  if (!subscribed && awaitingFeedback) {
    awaitingFeedback = false;
    incomingFeedback.store(0);
    if (Serial) Serial.println("UNCERTAIN: connection lost during an action; check the phone before retrying.");
    playError();
  }
}

void updateFeedback() {
  const uint8_t code = incomingFeedback.exchange(0);
  if (code && awaitingFeedback) {
    const uint8_t expected = pendingType == 3 ? 4 : pendingType;
    if (code != 3 && code != expected) {
      if (Serial) Serial.println("Ignoring unexpected feedback code for the current action.");
    } else {
      awaitingFeedback = false;
      if (Serial) { Serial.print("PHONE FEEDBACK code="); Serial.println(code); }
      switch (code) {
        case 1: playPattern(SAVED_PATTERN, 1, LED_GREEN); break;
        case 2: playPattern(WANT_PATTERN, 3, LED_GREEN); break;
        case 3: playError(); break;
        case 4: playPattern(UNDONE_PATTERN, 1, LED_GREEN); break;
      }
    }
  }
  if (awaitingFeedback && millis() - sentAt >= FEEDBACK_TIMEOUT_MS) {
    awaitingFeedback = false;
    if (Serial) Serial.println("UNCERTAIN: phone feedback timed out; check saved spots before retrying.");
    playError();
  }
}

bool startBluetooth() {
  Bluefruit.autoConnLed(false);
  if (!Bluefruit.begin(1, 0)) return false;
  Bluefruit.setName(DEVICE_NAME);
  Bluefruit.setTxPower(0);
  Bluefruit.Periph.setConnInterval(12, 24);
  if (clickerService.begin() != NRF_SUCCESS) return false;

  clickCharacteristic.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY);
  clickCharacteristic.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
  clickCharacteristic.setFixedLen(2);
  if (clickCharacteristic.begin() != NRF_SUCCESS) return false;
  const uint8_t empty[] = {0, 0};
  clickCharacteristic.write(empty, sizeof(empty));

  feedbackCharacteristic.setProperties(CHR_PROPS_WRITE | CHR_PROPS_WRITE_WO_RESP);
  feedbackCharacteristic.setPermission(SECMODE_NO_ACCESS, SECMODE_OPEN);
  feedbackCharacteristic.setFixedLen(1);
  feedbackCharacteristic.setWriteCallback(feedbackWritten);
  if (feedbackCharacteristic.begin() != NRF_SUCCESS) return false;

  if (!Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE)) return false;
  if (!Bluefruit.Advertising.addService(clickerService)) return false;
  if (!Bluefruit.ScanResponse.addName()) return false;
  Bluefruit.Advertising.restartOnDisconnect(true);
  Bluefruit.Advertising.setInterval(32, 244);
  Bluefruit.Advertising.setFastTimeout(30);
  return Bluefruit.Advertising.start(0);
}

void setup() {
  digitalWrite(MOTOR_PIN, LOW);
  // The 1 kOhm base resistor draws about 2–3 mA. P0.04 (D4) supports
  // high drive; keep the normal LOW drive and enable high HIGH drive.
  pinMode(MOTOR_PIN, OUTPUT_S0H1);
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  setPatternOutput(false);

  // Explicit low charge-current selection for this installed Seeed core.
  pinMode(PIN_CHARGING_CURRENT, INPUT);
  // Keep the battery-voltage divider enabled per Seeed charging guidance.
  digitalWrite(VBAT_ENABLE, LOW);
  pinMode(VBAT_ENABLE, OUTPUT);

  pinMode(BUTTON_PIN, INPUT_PULLUP);
  gestures.reset(digitalRead(BUTTON_PIN) == LOW, millis());
  Serial.begin(115200);
  // No wait for Serial: USB is a test input, never a startup requirement.
  bleReady = startBluetooth();
  if (!bleReady) digitalWrite(LED_RED, LOW);
}

void loop() {
  updatePhoneState();
  updateFeedback();
  readUSB();
  const uint8_t event = gestures.update(digitalRead(BUTTON_PIN) == LOW, millis());
  if (event) emitClick(event, "BUTTON");
  updatePattern();
  delay(1);
}
