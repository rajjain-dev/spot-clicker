#pragma once

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// Hardware-independent manual motor control for the USB test firmware:
// a command parser and a timing engine. A sequence is a list of step times
// in milliseconds that alternate ON, OFF, ON, ... starting with ON.
namespace motor {

enum : uint8_t { MAX_STEPS = 32 };
const uint32_t MAX_STEP_MS = 600000UL;   // 10 minutes for a single step
const uint32_t MAX_TOTAL_MS = 600000UL;  // 10 minutes for a whole command
const uint32_t ON_SAFETY_MS = 60000UL;   // plain "on" stops by itself after 60 s
const uint32_t LONG_TEST_MS = 10000UL;   // "m": the original 10-second test buzz
const uint32_t MAX_PATTERN_STEP_MS = 60000UL;
const uint16_t MAX_REPEATS = 1000;

enum class Kind : uint8_t {
  NotMotor,  // not a motor command; the caller handles it
  Invalid,   // a motor command with a problem; see error
  Run,       // start the sequence in steps/count/repeats
  Stop,      // motor off now
  Power,     // value = 10..100 %, or 0 to report the current setting
  Play,      // value = 1 Liked, 2 Want to go, 3 error, 4 undone
  Auto,      // value = 0 off, 1 on, 2 report the current setting
};

struct Command {
  Kind kind;
  uint32_t steps[MAX_STEPS];
  uint8_t count;
  uint16_t repeats;
  bool untilOff;  // plain "on": runs until "off", with the 60 s safety stop
  uint8_t value;
  const char* error;
};

// Total duration of a sequence, leaving out the OFF step that would end the
// final repeat (the engine finishes as soon as the last buzz ends).
inline uint64_t totalMs(const uint32_t* steps, uint8_t count, uint16_t repeats) {
  uint64_t once = 0;
  for (uint8_t i = 0; i < count; ++i) once += steps[i];
  uint64_t total = once * repeats;
  if (count > 1 && count % 2 == 0) total -= steps[count - 1];
  return total;
}

inline bool hasOnTime(const uint32_t* steps, uint8_t count) {
  for (uint8_t i = 0; i < count; i += 2)
    if (steps[i]) return true;
  return false;
}

// Strict unsigned decimal: digits only, value <= limit.
inline bool parseNumber(const char* text, uint32_t limit, uint32_t& out) {
  if (!text || !*text) return false;
  uint64_t value = 0;
  for (const char* p = text; *p; ++p) {
    if (*p < '0' || *p > '9') return false;
    value = value * 10 + static_cast<uint32_t>(*p - '0');
    if (value > limit) return false;
  }
  out = static_cast<uint32_t>(value);
  return true;
}

inline Command invalid(const char* error) {
  Command c;
  memset(&c, 0, sizeof(c));
  c.kind = Kind::Invalid;
  c.error = error;
  return c;
}

// Parses one line. Words may be separated by spaces, tabs or commas, and any
// letter case is accepted. Lines that are not motor commands return NotMotor.
inline Command parse(const char* line) {
  Command c;
  memset(&c, 0, sizeof(c));
  c.kind = Kind::NotMotor;
  c.repeats = 1;

  char buffer[256];
  strncpy(buffer, line ? line : "", sizeof(buffer) - 1);
  buffer[sizeof(buffer) - 1] = '\0';
  char* words[MAX_STEPS + 3];
  uint8_t n = 0;
  for (char* p = buffer; *p && n < sizeof(words) / sizeof(words[0]);) {
    while (*p == ' ' || *p == '\t' || *p == ',') *p++ = '\0';
    if (!*p) break;
    words[n++] = p;
    while (*p && *p != ' ' && *p != '\t' && *p != ',') {
      if (*p >= 'A' && *p <= 'Z') *p = static_cast<char>(*p - 'A' + 'a');
      ++p;
    }
  }
  if (n == 0) return c;
  const char* w = words[0];
  if (line && strlen(line) >= sizeof(buffer)) return invalid("line too long");
  if (n == sizeof(words) / sizeof(words[0])) return invalid("too many numbers (a pattern takes up to 32 steps)");

  if (!strcmp(w, "x") || !strcmp(w, "off") || !strcmp(w, "stop")) {
    if (n > 1) return invalid("off takes no numbers");
    c.kind = Kind::Stop;
    return c;
  }

  if (!strcmp(w, "m")) {
    if (n > 1) return invalid("m takes no numbers; use: on 2000");
    c.kind = Kind::Run;
    c.steps[0] = LONG_TEST_MS;
    c.count = 1;
    return c;
  }

  if (!strcmp(w, "on")) {
    if (n > 2) return invalid("use: on   or   on 2000");
    uint32_t ms = ON_SAFETY_MS;
    if (n == 2 && (!parseNumber(words[1], MAX_STEP_MS, ms) || ms == 0))
      return invalid("on time must be 1 to 600000 ms");
    c.kind = Kind::Run;
    c.steps[0] = ms;
    c.count = 1;
    c.untilOff = (n == 1);
    return c;
  }

  if (!strcmp(w, "pulse")) {
    if (n < 2 || n > 4) return invalid("use: pulse 200   or   pulse 200 3 150 (time, count, gap)");
    uint32_t ms = 0, count = 1, gap = 0;
    if (!parseNumber(words[1], MAX_PATTERN_STEP_MS, ms) || ms == 0)
      return invalid("pulse time must be 1 to 60000 ms");
    if (n >= 3 && (!parseNumber(words[2], MAX_REPEATS, count) || count == 0))
      return invalid("pulse count must be 1 to 1000");
    gap = ms;
    if (n == 4 && !parseNumber(words[3], MAX_PATTERN_STEP_MS, gap))
      return invalid("pulse gap must be 0 to 60000 ms");
    c.kind = Kind::Run;
    c.steps[0] = ms;
    c.count = 1;
    if (count > 1) {
      c.steps[1] = gap;
      c.count = 2;
      c.repeats = static_cast<uint16_t>(count);
    }
    if (totalMs(c.steps, c.count, c.repeats) > MAX_TOTAL_MS)
      return invalid("that would run longer than 10 minutes");
    return c;
  }

  if (!strcmp(w, "pattern")) {
    uint8_t last = n;
    uint32_t repeats = 1;
    const char* tail = words[n - 1];
    if (n >= 2 && (tail[0] == 'x' || tail[0] == '*')) {
      if (!parseNumber(tail + 1, MAX_REPEATS, repeats) || repeats == 0)
        return invalid("repeat must be x1 to x1000");
      last = static_cast<uint8_t>(n - 1);
    }
    if (last < 2) return invalid("use: pattern 100 50 100 400   (ON OFF ON OFF ... ms; add x3 to repeat)");
    if (last - 1 > MAX_STEPS) return invalid("a pattern takes up to 32 steps");
    for (uint8_t i = 1; i < last; ++i) {
      if (!parseNumber(words[i], MAX_PATTERN_STEP_MS, c.steps[i - 1]))
        return invalid("pattern steps must be 0 to 60000 ms");
    }
    c.count = static_cast<uint8_t>(last - 1);
    c.repeats = static_cast<uint16_t>(repeats);
    if (!hasOnTime(c.steps, c.count)) return invalid("the pattern has no ON time");
    if (totalMs(c.steps, c.count, c.repeats) > MAX_TOTAL_MS)
      return invalid("that would run longer than 10 minutes");
    c.kind = Kind::Run;
    return c;
  }

  if (!strcmp(w, "power")) {
    if (n > 2) return invalid("use: power 60   (10 to 100 %)");
    uint32_t pct = 0;
    if (n == 2 && (!parseNumber(words[1], 100, pct) || pct < 10))
      return invalid("power must be 10 to 100 %");
    c.kind = Kind::Power;
    c.value = static_cast<uint8_t>(pct);
    return c;
  }

  if (!strcmp(w, "play")) {
    if (n != 2) return invalid("use: play liked | want | error | undone");
    const char* name = words[1];
    uint8_t which = 0;
    if (!strcmp(name, "liked") || !strcmp(name, "1")) which = 1;
    else if (!strcmp(name, "want") || !strcmp(name, "2")) which = 2;
    else if (!strcmp(name, "error") || !strcmp(name, "3")) which = 3;
    else if (!strcmp(name, "undone") || !strcmp(name, "undo") || !strcmp(name, "4")) which = 4;
    else return invalid("use: play liked | want | error | undone");
    c.kind = Kind::Play;
    c.value = which;
    return c;
  }

  if (!strcmp(w, "auto")) {
    if (n > 2) return invalid("use: auto on   or   auto off");
    c.kind = Kind::Auto;
    c.value = 2;
    if (n == 2) {
      if (!strcmp(words[1], "on")) c.value = 1;
      else if (!strcmp(words[1], "off")) c.value = 0;
      else return invalid("use: auto on   or   auto off");
    }
    return c;
  }

  return c;  // NotMotor
}

// Plays a sequence without blocking. Call update() often with millis(); it
// returns true while the motor should be ON and catches up after delays.
class Engine {
 public:
  bool start(const uint32_t* steps, uint8_t count, uint16_t repeats, uint32_t now) {
    if (!steps || count == 0 || count > MAX_STEPS || repeats == 0) return false;
    if (!hasOnTime(steps, count) || totalMs(steps, count, repeats) > MAX_TOTAL_MS) return false;
    memcpy(steps_, steps, count * sizeof(steps[0]));
    count_ = count;
    repeatsLeft_ = repeats;
    index_ = 0;
    stepStartedAt_ = now;
    active_ = true;
    finished_ = false;
    return true;
  }

  void stop() {
    active_ = false;
    finished_ = false;
  }

  bool active() const { return active_; }

  bool update(uint32_t now) {
    while (active_) {
      // The final repeat ends with its last buzz; skip a trailing OFF step.
      if ((index_ & 1) && index_ + 1 == count_ && repeatsLeft_ == 1) {
        finish();
        break;
      }
      const uint32_t step = steps_[index_];
      if (now - stepStartedAt_ < step) return (index_ & 1) == 0;
      stepStartedAt_ += step;
      if (++index_ >= count_) {
        index_ = 0;
        if (--repeatsLeft_ == 0) finish();
      }
    }
    return false;
  }

  // True once after a sequence ends by itself (not after stop()).
  bool takeFinished() {
    const bool finished = finished_;
    finished_ = false;
    return finished;
  }

  uint32_t remainingMs(uint32_t now) const {
    if (!active_) return 0;
    uint64_t left = 0;
    const uint32_t elapsed = now - stepStartedAt_;
    left += steps_[index_] > elapsed ? steps_[index_] - elapsed : 0;
    for (uint8_t i = static_cast<uint8_t>(index_ + 1); i < count_; ++i) left += steps_[i];
    uint64_t once = 0;
    for (uint8_t i = 0; i < count_; ++i) once += steps_[i];
    left += once * (repeatsLeft_ - 1);
    if (count_ > 1 && count_ % 2 == 0 && !(repeatsLeft_ == 1 && index_ == count_ - 1)) left -= steps_[count_ - 1];
    return static_cast<uint32_t>(left);
  }

 private:
  void finish() {
    active_ = false;
    finished_ = true;
  }

  uint32_t steps_[MAX_STEPS] = {};
  uint8_t count_ = 0;
  uint8_t index_ = 0;
  uint16_t repeatsLeft_ = 0;
  uint32_t stepStartedAt_ = 0;
  bool active_ = false;
  bool finished_ = false;
};

}  // namespace motor
