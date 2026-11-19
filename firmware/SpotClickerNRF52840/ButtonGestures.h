#pragma once

#include <stdint.h>

// Hardware-independent gesture recognizer. Return values match the iPhone
// protocol: 0 = no action, 1 = single, 2 = double, 3 = hold.
class ButtonGestures {
 public:
  void reset(bool pressed, uint32_t now) {
    rawPressed_ = stablePressed_ = pressed;
    armed_ = !pressed;
    rawChangedAt_ = pressedAt_ = releasedAt_ = now;
    clicks_ = 0;
    holdSent_ = false;
  }

  bool pressed() const { return armed_ && stablePressed_; }

  uint8_t update(bool pressed, uint32_t now) {
    uint8_t event = 0;
    if (pressed != rawPressed_) {
      rawPressed_ = pressed;
      rawChangedAt_ = now;
    }

    if (rawPressed_ != stablePressed_ && now - rawChangedAt_ >= 25) {
      stablePressed_ = rawPressed_;
      if (!armed_) {
        // A button held during startup must first be released cleanly.
        if (!stablePressed_) armed_ = true;
        return 0;
      }
      if (stablePressed_) {
        // Flush an expired first click before beginning a separate gesture.
        // Use the raw press time so debounce does not shorten the double gap.
        if (clicks_ && rawChangedAt_ - releasedAt_ > 350) {
          event = 1;
          clicks_ = 0;
        }
        pressedAt_ = now;
        holdSent_ = false;
      } else if (!holdSent_) {
        if (clicks_) {
          clicks_ = 0;
          return 2;
        }
        clicks_ = 1;
        releasedAt_ = now;
      }
    }

    if (!armed_) return 0;
    if (stablePressed_ && !holdSent_ && now - pressedAt_ >= 800) {
      holdSent_ = true;
      clicks_ = 0;
      return 3;
    }
    // Do not emit the pending single while a second press is being held.
    if (!stablePressed_ && !rawPressed_ && clicks_ && now - releasedAt_ >= 350) {
      clicks_ = 0;
      return 1;
    }
    return event;
  }

 private:
  bool rawPressed_ = false;
  bool stablePressed_ = false;
  bool armed_ = true;
  bool holdSent_ = false;
  uint8_t clicks_ = 0;
  uint32_t rawChangedAt_ = 0;
  uint32_t pressedAt_ = 0;
  uint32_t releasedAt_ = 0;
};
