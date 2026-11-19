#include "../SpotClickerNRF52840/MotorControl.h"

#include <assert.h>
#include <iostream>
#include <string>
#include <vector>

using motor::Command;
using motor::Kind;

// Runs a sequence on a simulated 1 ms clock and returns the motor's ON/OFF edges
// as (time, on) pairs, plus the time it finished.
struct Run {
  std::vector<std::pair<uint32_t, bool>> edges;
  uint32_t finishedAt = 0;
};

Run simulate(const Command& c, uint32_t start = 0, uint32_t limit = 700000) {
  motor::Engine engine;
  assert(engine.start(c.steps, c.count, c.repeats, start));
  Run run;
  bool on = false;
  for (uint32_t t = 0; t <= limit; ++t) {
    const bool want = engine.update(start + t);
    if (want != on) {
      run.edges.push_back({t, want});
      on = want;
    }
    if (engine.takeFinished()) {
      run.finishedAt = t;
      break;
    }
  }
  assert(!engine.active());
  return run;
}

int main() {
  int checks = 0;
#define expect(cond) do { if (!(cond)) { std::cerr << "FAILED line " << __LINE__ << ": " #cond "\n"; return 1; } ++checks; } while (0)

  // Plain on: until off, with the 60 s safety stop.
  Command c = motor::parse("on");
  expect(c.kind == Kind::Run && c.count == 1 && c.steps[0] == 60000 && c.untilOff);
  c = motor::parse("ON 2500");
  expect(c.kind == Kind::Run && c.steps[0] == 2500 && !c.untilOff);
  expect(motor::parse("on 0").kind == Kind::Invalid);
  expect(motor::parse("on 600001").kind == Kind::Invalid);
  expect(motor::parse("on -5").kind == Kind::Invalid);
  expect(motor::parse("on 12ab").kind == Kind::Invalid);

  // Off and the old one-letter commands.
  expect(motor::parse("off").kind == Kind::Stop);
  expect(motor::parse("x").kind == Kind::Stop);
  expect(motor::parse("  X  ").kind == Kind::Stop);
  c = motor::parse("m");
  expect(c.kind == Kind::Run && c.steps[0] == 10000);

  // Pulses.
  c = motor::parse("pulse 200");
  expect(c.kind == Kind::Run && c.count == 1 && c.steps[0] == 200);
  Run r = simulate(c);
  expect(r.edges.size() == 2 && r.edges[0].first == 0 && r.edges[1].first == 200 && r.finishedAt == 200);
  c = motor::parse("pulse 120 3 80");
  expect(c.kind == Kind::Run && c.count == 2 && c.repeats == 3 && c.steps[1] == 80);
  r = simulate(c);
  // 3 buzzes: 0-120, 200-320, 400-520; finishes when the last buzz ends.
  expect(r.edges.size() == 6 && r.edges[2].first == 200 && r.edges[4].first == 400 && r.finishedAt == 520);
  c = motor::parse("pulse 100 2");  // gap defaults to the buzz time
  r = simulate(c);
  expect(r.edges.size() == 4 && r.edges[2].first == 200 && r.finishedAt == 300);
  expect(motor::parse("pulse").kind == Kind::Invalid);
  expect(motor::parse("pulse 0").kind == Kind::Invalid);
  expect(motor::parse("pulse 100 0").kind == Kind::Invalid);
  expect(motor::parse("pulse 60000 1000 60000").kind == Kind::Invalid);  // over 10 minutes

  // Patterns, with commas and a repeat.
  c = motor::parse("pattern 100,50,300");
  expect(c.kind == Kind::Run && c.count == 3 && c.repeats == 1);
  r = simulate(c);
  expect(r.edges.size() == 4 && r.edges[1].first == 100 && r.edges[2].first == 150 && r.finishedAt == 450);
  c = motor::parse("pattern 100 100 x3");
  r = simulate(c);
  expect(r.edges.size() == 6 && r.finishedAt == 500);
  c = motor::parse("Pattern 0 100 200");  // starts with a pause
  r = simulate(c);
  expect(r.edges.size() == 2 && r.edges[0].first == 100 && r.finishedAt == 300);
  expect(motor::parse("pattern").kind == Kind::Invalid);
  expect(motor::parse("pattern x3").kind == Kind::Invalid);
  expect(motor::parse("pattern 0 500").kind == Kind::Invalid);  // no ON time
  expect(motor::parse("pattern 100 100 x0").kind == Kind::Invalid);
  std::string longest = "pattern";
  for (int i = 0; i < 32; ++i) longest += " 60000";
  expect(motor::parse(longest.c_str()).kind == Kind::Invalid);  // 32 x 60 s > 10 min
  std::string many = "pattern";
  for (int i = 0; i < 32; ++i) many += " 10";
  expect(motor::parse(many.c_str()).kind == Kind::Run);
  expect(motor::parse((many + " 10").c_str()).kind == Kind::Invalid);  // 33 steps

  // Power, play and auto.
  c = motor::parse("power 60");
  expect(c.kind == Kind::Power && c.value == 60);
  expect(motor::parse("power").kind == Kind::Power && motor::parse("power").value == 0);
  expect(motor::parse("power 5").kind == Kind::Invalid);
  expect(motor::parse("power 101").kind == Kind::Invalid);
  expect(motor::parse("play want").kind == Kind::Play && motor::parse("play want").value == 2);
  expect(motor::parse("play undo").value == 4);
  expect(motor::parse("play loud").kind == Kind::Invalid);
  expect(motor::parse("auto on").kind == Kind::Auto && motor::parse("auto on").value == 1);
  expect(motor::parse("auto off").value == 0);
  expect(motor::parse("auto").value == 2);

  // Lines that belong to the rest of the firmware.
  expect(motor::parse("1").kind == Kind::NotMotor);
  expect(motor::parse("s").kind == Kind::NotMotor);
  expect(motor::parse("").kind == Kind::NotMotor);

  // Stop, restart and timer wrap-around.
  motor::Engine engine;
  c = motor::parse("on 1000");
  expect(engine.start(c.steps, c.count, c.repeats, 0) && engine.update(10));
  engine.stop();
  expect(!engine.update(20) && !engine.active() && !engine.takeFinished());
  expect(engine.start(c.steps, c.count, c.repeats, 30) && engine.update(1029) && !engine.update(1030));
  expect(engine.takeFinished());
  c = motor::parse("pulse 100 2 100");
  r = simulate(c, UINT32_MAX - 150);
  expect(r.edges.size() == 4 && r.finishedAt == 300);
  // Catching up after the loop was delayed.
  expect(engine.start(c.steps, c.count, c.repeats, 0) && !engine.update(5000) && engine.takeFinished());
  // Remaining time.
  c = motor::parse("pulse 100 3 50");
  expect(engine.start(c.steps, c.count, c.repeats, 0) && engine.remainingMs(0) == 400);
  expect(!engine.update(120) && engine.remainingMs(120) == 280);
  expect(engine.update(160) && engine.remainingMs(160) == 240);

  std::cout << checks << " motor control checks passed\n";
}
