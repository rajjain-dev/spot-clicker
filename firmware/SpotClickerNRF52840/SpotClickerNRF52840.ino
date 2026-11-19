/*
  Spot Clicker — plain Seeed XIAO nRF52840, Seeed nRF52 Boards 1.1.13.
  Target: Seeeduino:nrf52:xiaonRF52840 (non-mbed / Bluefruit).

  USB commands at 115200 baud, one per line (no external button required):
    1 = single / Liked, 2 = double / Want to go, 3 or h = hold / undo
    s = status, l = BLUE LED test only, ? = help
  Motor: runs in the background, as often as you like, without replugging:
    on           motor on until "off" (stops by itself after 60 s)
    on 2000      on for 2000 ms (up to 600000)
    off or x     motor off now
    pulse 200 3 150     three 200 ms buzzes with 150 ms gaps (count and gap optional)
    pattern 100 50 100 400 x3   ON OFF ON OFF ... ms, optional repeat (up to 32 steps)
    power 60     strength 10-100 % (below 100 uses ~31 kHz PWM); "power" alone reports it
    play liked | want | error | undone   the phone-feedback patterns, on the motor
    auto on | off    vibrate for save, undo and error feedback (starts on)
    m            10 s buzz (the original test)
  Every motor command replaces the one running. Nothing is limited to once per boot.
  Both USB and the momentary key on D1-to-GND use emitClick().

  Current USB-only test: USB powers the XIAO; its 3V3 powers the motor driver.
  Battery and bench supply remain disconnected. D4 controls the base through 1k.
  This test does not establish electrical limits.
  Phone feedback: 1 Liked, 2 Want to go, 3 error, 4 undone.
  Green patterns mean a result from the phone; red means error/uncertainty.
  USB commands bypass physical gesture timing, not Bluetooth or phone storage.
*/

#include <Adafruit_TinyUSB.h>
#include <bluefruit.h>
#include <HardwarePWM.h>
#include <atomic>
#include "ButtonGestures.h"
#include "MotorControl.h"

constexpr char DEVICE_NAME[] = "SpotClicker";
constexpr char SERVICE_UUID[] = "7A1C0001-5B3E-4D2A-9F10-3C5D8E2B6A01";
constexpr char CLICK_UUID[] = "7A1C0002-5B3E-4D2A-9F10-3C5D8E2B6A01";
constexpr char FEEDBACK_UUID[] = "7A1C0003-5B3E-4D2A-9F10-3C5D8E2B6A01";
constexpr uint8_t BUTTON_PIN = D1;
constexpr uint8_t MOTOR_PIN = D4;
constexpr uint8_t LED_OFF = UINT8_MAX;
constexpr uint32_t BUTTON_FLASH_MS = 180;
constexpr uint32_t BUTTON_FLASH_GAP_MS = 75;
constexpr uint32_t FEEDBACK_TIMEOUT_MS = 15000;
constexpr uint32_t MOTOR_PWM_TOKEN = 0x524F544DUL;  // any non-zero value; marks the PWM block as ours
constexpr uint32_t LINE_IDLE_MS = 250;     // a line without Enter is used after this pause

BLEService clickerService(SERVICE_UUID);
BLECharacteristic clickCharacteristic(CLICK_UUID);
BLECharacteristic feedbackCharacteristic(FEEDBACK_UUID);
ButtonGestures gestures;
std::atomic<uint8_t> incomingFeedback{0};

const uint16_t SAVED_PATTERN[] = {150};
const uint16_t WANT_PATTERN[] = {90, 90, 90};
const uint16_t ERROR_PATTERN[] = {60, 60, 60, 60, 60};
const uint16_t UNDONE_PATTERN[] = {450};
const uint32_t LIKED_BUZZ[] = {300};
const uint32_t WANT_BUZZ[] = {250, 180, 250};
const uint32_t ERROR_BUZZ[] = {180, 140, 180, 140, 180};
const uint32_t UNDONE_BUZZ[] = {750};

struct FeedbackPattern {
  const char* name;
  const uint16_t* ledSteps;
  const uint32_t* motorSteps;
  uint8_t stepCount;
  uint8_t led;
};

// Entries follow the phone's feedback codes 1 through 4.
const FeedbackPattern FEEDBACK_PATTERNS[] = {
  {"liked", SAVED_PATTERN, LIKED_BUZZ, 1, LED_GREEN},
  {"want", WANT_PATTERN, WANT_BUZZ, 3, LED_GREEN},
  {"error", ERROR_PATTERN, ERROR_BUZZ, 5, LED_RED},
  {"undone", UNDONE_PATTERN, UNDONE_BUZZ, 1, LED_GREEN},
};

const uint16_t LED_TEST_PATTERN[] = {120};
const uint16_t* activePattern = nullptr;
uint8_t patternLength = 0;
uint8_t patternStep = 0;
uint8_t patternLed = LED_RED;
uint32_t patternStartedAt = 0;
enum class ButtonFlash : uint8_t { Idle, On, Gap };
ButtonFlash buttonFlash = ButtonFlash::Idle;
uint8_t pendingButtonFlashes = 0;
uint32_t buttonFlashStartedAt = 0;
uint32_t buttonFlashPhaseStartedAt = 0;

bool bleReady = false;
bool previousConnected = false;
bool previousSubscribed = false;
bool serialWasOpen = false;
bool awaitingFeedback = false;
uint8_t sequence = 0;
uint8_t pendingType = 0;
uint32_t sentAt = 0;

// Motor state. The engine decides ON/OFF; motorOutput() drives D4.
motor::Engine motorEngine;
bool motorFromAuto = false;        // the running sequence came from automatic feedback
bool motorOn = false;              // what D4 is currently doing
bool autoMotor = true;
uint8_t motorPowerPct = 100;
HardwarePWM* motorPwm = nullptr;   // only attached while power is below 100 %

char lineBuffer[256];
uint16_t lineLength = 0;
bool lineTooLong = false;
uint32_t lastCharAt = 0;

// ---------- motor output ----------

uint16_t motorDuty() {
  return static_cast<uint16_t>((motorPowerPct * 255U + 50U) / 100U);
}

bool attachMotorPwm() {
  if (motorPwm) return true;
  for (uint8_t i = 0; i < HWPWM_MODULE_NUM; ++i) {
    if (HwPWMx[i]->takeOwnership(MOTOR_PWM_TOKEN)) {
      motorPwm = HwPWMx[i];
      break;
    }
  }
  if (!motorPwm) return false;
  motorPwm->setResolution(8);                            // duty 0..255
  motorPwm->setClockDiv(PWM_PRESCALER_PRESCALER_DIV_2);  // 8 MHz / 255 = about 31 kHz, above hearing
  if (!motorPwm->addPin(MOTOR_PIN)) {
    motorPwm->releaseOwnership(MOTOR_PWM_TOKEN);
    motorPwm = nullptr;
    return false;
  }
  // addPin() resets D4 to standard drive; restore high drive for the base resistor.
  pinMode(MOTOR_PIN, OUTPUT_S0H1);
  return true;
}

void detachMotorPwm() {
  if (!motorPwm) return;
  motorPwm->removePin(MOTOR_PIN);
  motorPwm->stop();
  motorPwm->releaseOwnership(MOTOR_PWM_TOKEN);
  motorPwm = nullptr;
  pinMode(MOTOR_PIN, OUTPUT_S0H1);
}

void motorOutput(bool on) {
  motorOn = on;
  if (motorPowerPct >= 100) {
    detachMotorPwm();
    digitalWrite(MOTOR_PIN, on ? HIGH : LOW);
    return;
  }
  if (!on && !motorPwm) {
    digitalWrite(MOTOR_PIN, LOW);
    return;
  }
  if (!attachMotorPwm()) {
    // No free PWM block: fall back to full strength rather than doing nothing.
    digitalWrite(MOTOR_PIN, on ? HIGH : LOW);
    return;
  }
  motorPwm->writePin(MOTOR_PIN, on ? motorDuty() : 0);
}

void motorIdle() {
  detachMotorPwm();
  digitalWrite(MOTOR_PIN, LOW);
  motorOn = false;
}

bool startMotor(const uint32_t* steps, uint8_t count, uint16_t repeats, bool fromAuto) {
  if (!motorEngine.start(steps, count, repeats, millis())) return false;
  motorFromAuto = fromAuto;
  motorOutput(motorEngine.update(millis()));
  return true;
}

void stopMotor() {
  motorEngine.stop();
  motorFromAuto = false;
  motorIdle();
}

void updateMotor() {
  const bool want = motorEngine.update(millis());
  if (motorEngine.takeFinished()) {
    motorIdle();
    if (Serial) Serial.println(motorFromAuto ? "AUTO vibration done; D4 LOW."
                                            : "MOTOR done; D4 LOW.");
    motorFromAuto = false;
    return;
  }
  if (want != motorOn) motorOutput(want);
}

void playFeedbackBuzz(const FeedbackPattern& pattern, bool fromAuto) {
  if (fromAuto && (!autoMotor || (motorEngine.active() && !motorFromAuto))) return;
  if (startMotor(pattern.motorSteps, pattern.stepCount, 1, fromAuto) && Serial) {
    Serial.print(fromAuto ? "AUTO vibration " : "MOTOR play ");
    Serial.print(pattern.name);
    Serial.print(", power "); Serial.print(motorPowerPct); Serial.println(" %.");
  }
}

// ---------- LED patterns ----------

void setLedOutput(uint8_t led) {
  digitalWrite(LED_RED, led == LED_RED ? LOW : HIGH);
  digitalWrite(LED_GREEN, led == LED_GREEN ? LOW : HIGH);
  digitalWrite(LED_BLUE, led == LED_BLUE ? LOW : HIGH);
}

void flashButtonLed(uint32_t now) {
  if (buttonFlash != ButtonFlash::Idle) {
    if (pendingButtonFlashes < UINT8_MAX) ++pendingButtonFlashes;
    return;
  }
  buttonFlash = ButtonFlash::On;
  buttonFlashStartedAt = now;
  buttonFlashPhaseStartedAt = now;
  setLedOutput(LED_BLUE);
}

void playLedPattern(const uint16_t* steps, uint8_t length, uint8_t led) {
  activePattern = steps;
  patternLength = length;
  patternStep = 0;
  patternLed = led;
  patternStartedAt = millis();
  if (buttonFlash == ButtonFlash::Idle) setLedOutput(led);
}

void playFeedback(uint8_t code) {
  const FeedbackPattern& pattern = FEEDBACK_PATTERNS[code - 1];
  playLedPattern(pattern.ledSteps, pattern.stepCount, pattern.led);
  playFeedbackBuzz(pattern, true);
}

void playError() {
  playFeedback(3);
}

void updatePattern() {
  const uint32_t now = millis();
  if (buttonFlash == ButtonFlash::Gap) {
    if (now - buttonFlashPhaseStartedAt >= BUTTON_FLASH_GAP_MS) {
      buttonFlash = ButtonFlash::On;
      buttonFlashPhaseStartedAt = now;
      setLedOutput(LED_BLUE);
    }
    return;
  }
  const bool flashEnded = buttonFlash == ButtonFlash::On;
  if (flashEnded) {
    if (now - buttonFlashPhaseStartedAt < BUTTON_FLASH_MS) return;
    if (pendingButtonFlashes) {
      --pendingButtonFlashes;
      buttonFlash = ButtonFlash::Gap;
      buttonFlashPhaseStartedAt = now;
      setLedOutput(LED_OFF);
      return;
    }
    buttonFlash = ButtonFlash::Idle;
    const uint32_t flashTime = now - buttonFlashStartedAt;
    // Resume the result pattern from where blue covered it. A result can also
    // arrive during the flash, so pause only for the part that overlapped.
    if (activePattern) {
      const uint32_t patternTime = now - patternStartedAt;
      patternStartedAt += min(flashTime, patternTime);
    }
  }

  const bool stepEnded = activePattern && now - patternStartedAt >= activePattern[patternStep];
  if (stepEnded) {
    patternStartedAt = now;
    if (++patternStep >= patternLength) activePattern = nullptr;
  }
  if (flashEnded || stepEnded) {
    const uint8_t idleLed = !activePattern && !bleReady ? LED_RED : LED_OFF;
    setLedOutput(activePattern && patternStep % 2 == 0 ? patternLed : idleLed);
  }
}

bool phoneConnected() {
  return bleReady && Bluefruit.Periph.connected() > 0;
}

bool phoneSubscribed() {
  return phoneConnected() && clickCharacteristic.notifyEnabled();
}

void printMotorState() {
  if (!Serial) return;
  Serial.print("Motor: ");
  if (motorEngine.active()) {
    Serial.print("running");
    if (motorFromAuto) Serial.print(" (automatic feedback)");
    Serial.print(", about "); Serial.print(motorEngine.remainingMs(millis())); Serial.println(" ms left.");
  } else {
    Serial.println("off.");
  }
  Serial.print("Motor power: "); Serial.print(motorPowerPct);
  Serial.println(motorPowerPct >= 100 ? " % (plain on/off)." : " % (PWM, about 31 kHz).");
  Serial.print("Automatic feedback vibration: "); Serial.println(autoMotor ? "on" : "off");
}

void printStatus() {
  if (!Serial) return;
  Serial.println("STATUS SpotClicker nRF52840 USB-motor-test v8");
  Serial.print("Uptime ms: "); Serial.println(millis());
  Serial.print("BLE initialized: "); Serial.println(bleReady ? "yes" : "no");
  Serial.print("Advertising: "); Serial.println(bleReady && Bluefruit.Advertising.isRunning() ? "yes" : "no");
  Serial.print("Phone connected: "); Serial.println(phoneConnected() ? "yes" : "no");
  Serial.print("Notifications subscribed: "); Serial.println(phoneSubscribed() ? "yes" : "no");
  Serial.print("Awaiting phone feedback: "); Serial.println(awaitingFeedback ? "yes" : "no");
  printMotorState();
  Serial.println("Motor control: D4 through 1 kOhm to transistor base; motor power from XIAO 3V3.");
  Serial.print("Service UUID: "); Serial.println(SERVICE_UUID);
  Serial.print("Click UUID: "); Serial.println(CLICK_UUID);
  Serial.print("Feedback UUID: "); Serial.println(FEEDBACK_UUID);
  Serial.println("No disconnected-click queue. Wait for the phone result before another action.");
}

void printHelp() {
  if (!Serial) return;
  Serial.println("USB: 1=Liked, 2=Want to go, 3/h=undo, s=status, l=BLUE LED test, ?=help");
  Serial.println("Motor: on | on 2000 | off (or x) | pulse 200 | pulse 200 3 150 | pattern 100 50 100 400 x3");
  Serial.println("       power 60 (10-100 %) | play liked|want|error|undone | auto on|off | m = 10 s buzz");
  Serial.println("'on' alone stops by itself after 60 s. Each motor command replaces the one running.");
  Serial.println("Blue flashes on each button press. Green confirms success; red signals an error.");
  Serial.println("Save, undo and error vibration is on at startup; use 'auto off' to mute it.");
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

// ---------- USB command lines ----------

void handleMotorCommand(const motor::Command& c) {
  switch (c.kind) {
    case motor::Kind::Invalid:
      if (Serial) { Serial.print("MOTOR ERROR: "); Serial.print(c.error); Serial.println(". Send ? for help."); }
      break;
    case motor::Kind::Stop:
      stopMotor();
      if (Serial) Serial.println("MOTOR off; D4 LOW.");
      break;
    case motor::Kind::Run:
      if (!startMotor(c.steps, c.count, c.repeats, false)) {
        if (Serial) Serial.println("MOTOR ERROR: could not start that sequence.");
        break;
      }
      if (Serial) {
        if (c.untilOff) Serial.print("MOTOR on until 'off' (stops by itself after 60 s)");
        else if (c.count == 1 && c.repeats == 1) { Serial.print("MOTOR on for "); Serial.print(c.steps[0]); Serial.print(" ms"); }
        else {
          Serial.print("MOTOR sequence: "); Serial.print(c.count); Serial.print(c.count == 1 ? " step" : " steps");
          if (c.repeats > 1) { Serial.print(" x"); Serial.print(c.repeats); }
          Serial.print(", "); Serial.print(static_cast<uint32_t>(motor::totalMs(c.steps, c.count, c.repeats))); Serial.print(" ms");
        }
        Serial.print(", power "); Serial.print(motorPowerPct); Serial.println(" %.");
      }
      break;
    case motor::Kind::Power:
      if (c.value) {
        motorPowerPct = c.value;
        if (motorOn) motorOutput(true);  // apply to a buzz that is already running
        else if (!motorEngine.active()) motorIdle();
      }
      if (Serial) {
        Serial.print("POWER "); Serial.print(motorPowerPct);
        Serial.println(motorPowerPct >= 100 ? " % (plain on/off)." : " % (PWM, about 31 kHz).");
      }
      break;
    case motor::Kind::Play:
      playFeedbackBuzz(FEEDBACK_PATTERNS[c.value - 1], false);
      break;
    case motor::Kind::Auto:
      if (c.value <= 1) autoMotor = (c.value == 1);
      if (Serial) { Serial.print("AUTO feedback vibration: "); Serial.println(autoMotor ? "on" : "off"); }
      break;
    case motor::Kind::NotMotor:
      break;
  }
}

void handleLine(char* line) {
  while (*line == ' ' || *line == '\t') ++line;
  size_t length = strlen(line);
  while (length && (line[length - 1] == ' ' || line[length - 1] == '\t')) line[--length] = '\0';
  if (!length) return;

  if (length == 1) {
    const char command = line[0];
    if (command >= '1' && command <= '3') { emitClick(command - '0', "USB"); return; }
    if (command == 'h' || command == 'H') { emitClick(3, "USB"); return; }
    if (command == 's' || command == 'S') { printStatus(); return; }
    if (command == '?') { printHelp(); return; }
    if (command == 'l' || command == 'L') {
      if (!awaitingFeedback) {
        if (Serial) Serial.println("TEST BLUE LED only; no click sent and no spot saved.");
        playLedPattern(LED_TEST_PATTERN, 1, LED_BLUE);
      }
      return;
    }
  }
  if (!strcasecmp(line, "status")) { printStatus(); return; }
  if (!strcasecmp(line, "help")) { printHelp(); return; }

  const motor::Command c = motor::parse(line);
  if (c.kind == motor::Kind::NotMotor) {
    if (Serial) Serial.println("Unknown USB command; send ? for help.");
    return;
  }
  handleMotorCommand(c);
}

void finishLine() {
  lineBuffer[lineLength] = '\0';
  if (lineTooLong) {
    if (Serial) Serial.println("REJECTED: line too long.");
  } else {
    handleLine(lineBuffer);
  }
  lineLength = 0;
  lineTooLong = false;
}

void readUSB() {
  const bool open = static_cast<bool>(Serial);
  if (open && !serialWasOpen) { printHelp(); printStatus(); }
  serialWasOpen = open;
  // Bound the work per loop so a stream of USB data cannot starve BLE/feedback.
  for (uint8_t count = 0; count < 64 && Serial.available(); ++count) {
    const char c = Serial.read();
    lastCharAt = millis();
    if (c == '\r' || c == '\n') {
      if (lineLength || lineTooLong) finishLine();
      continue;
    }
    if (lineLength < sizeof(lineBuffer) - 1) lineBuffer[lineLength++] = c;
    else lineTooLong = true;
  }
  // Serial Monitor set to "No line ending": use the line after a short pause.
  if ((lineLength || lineTooLong) && millis() - lastCharAt >= LINE_IDLE_MS) finishLine();
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
      playFeedback(code);
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
  setLedOutput(LED_OFF);

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
  if (!bleReady) setLedOutput(LED_RED);
}

void loop() {
  updatePhoneState();
  updateFeedback();
  readUSB();
  const uint32_t now = millis();
  const bool wasPressed = gestures.pressed();
  const uint8_t event = gestures.update(digitalRead(BUTTON_PIN) == LOW, now);
  if (!wasPressed && gestures.pressed()) flashButtonLed(now);
  if (event) emitClick(event, "BUTTON");
  updatePattern();
  updateMotor();
  delay(1);
}
