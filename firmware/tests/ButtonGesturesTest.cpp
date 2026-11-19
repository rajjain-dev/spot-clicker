#include "../SpotClickerNRF52840/ButtonGestures.h"

#include <assert.h>
#include <initializer_list>
#include <iostream>
#include <utility>
#include <vector>

using Edge = std::pair<uint32_t, bool>;

std::vector<uint8_t> simulate(std::initializer_list<Edge> edges, uint32_t end,
                              bool initiallyPressed = false, uint32_t start = 0) {
  ButtonGestures button;
  button.reset(initiallyPressed, start);
  bool pressed = initiallyPressed;
  auto next = edges.begin();
  std::vector<uint8_t> events;
  for (uint32_t elapsed = 0; elapsed <= end; ++elapsed) {
    while (next != edges.end() && next->first == elapsed) {
      pressed = next->second;
      ++next;
    }
    const uint8_t event = button.update(pressed, start + elapsed);
    if (event) events.push_back(event);
  }
  return events;
}

int main() {
  assert((simulate({{50, true}, {150, false}}, 900) == std::vector<uint8_t>{1}));
  assert((simulate({{50, true}, {100, false}, {250, true}, {300, false}}, 900)
          == std::vector<uint8_t>{2}));
  assert((simulate({{50, true}, {1200, false}}, 2000) == std::vector<uint8_t>{3}));
  assert((simulate({{50, true}, {10000, false}}, 11000) == std::vector<uint8_t>{3}));
  assert((simulate({{50, true}, {55, false}, {60, true}, {65, false},
                    {70, true}, {160, false}}, 900) == std::vector<uint8_t>{1}));
  assert((simulate({{50, true}, {100, false}, {250, true}, {1300, false}}, 2000)
          == std::vector<uint8_t>{3}));
  assert((simulate({{50, true}, {100, false}, {700, true}, {750, false}}, 1500)
          == std::vector<uint8_t>{1, 1}));
  // Second raw press precedes the double deadline, but its debounce ends later.
  assert((simulate({{50, true}, {100, false}, {460, true}, {520, false}}, 1100)
          == std::vector<uint8_t>{2}));
  // Held during boot: releasing must not create a click or undo.
  assert((simulate({{100, false}}, 1200, true).empty()));
  assert((simulate({{100, false}, {300, true}, {400, false}}, 1200, true)
          == std::vector<uint8_t>{1}));
  // Arduino millis() wraps; elapsed-time subtraction must continue to work.
  assert((simulate({{50, true}, {150, false}}, 900, false, UINT32_MAX - 200)
          == std::vector<uint8_t>{1}));
  std::cout << "11 gesture scenarios passed\n";
}
