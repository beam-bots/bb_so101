<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# Run in Simulation

`bb_so101`'s generated `application.ex` reads the `SIMULATE` environment
variable on boot. When it's set to any non-empty value, the robot boots in
`:kinematic` simulation mode — no Feetech controller, no serial port, no
hardware required.

## Start the server in simulation mode

```bash
SIMULATE=1 mix phx.server
```

The dashboard at <http://localhost:4000> behaves exactly as it does with real
hardware, with two differences:

- `BB.Sim.Actuator` replaces `BB.Servo.Feetech.Actuator`. It publishes a
  `BeginMotion` message with timing computed from the joint's velocity limit,
  so the 3D view animates as the simulated arm "moves".
- The Feetech controller is omitted from the supervision tree. Anything that
  inspects controllers (e.g. parameter bridges over the bus) will report it as
  absent.

The safety system is still enforced: you must arm the robot before any
command is allowed to mutate joint state.

## How it works

The generated `application.ex` looks like this:

```elixir
defp robot_opts do
  if System.get_env("SIMULATE") do
    [simulation: :kinematic]
  else
    [params: [config: [feetech: [device: "/dev/ttyUSB0"]]]]
  end
end
```

When `SIMULATE` is set, the robot is started with `simulation: :kinematic`.
`BB`'s supervisor reads that option and:

- Omits any controller with `simulation: :omit` set (which the Feetech
  controller does in the generated robot).
- Replaces each actuator's module with `BB.Sim.Actuator`.

Everything else — kinematic chain, command system, parameters, PubSub topics —
runs unchanged.

## Mixing simulation and real hardware

There's no built-in option to simulate _some_ joints and drive others on real
hardware. If you need that, define a second robot module with the joints you
want to simulate (omit the actuators) and supervise both — Beam Bots is happy
to run multiple robots in one BEAM.

## IEx, tests, and CI

You can drop `SIMULATE=1` on any command that boots the application:

```bash
SIMULATE=1 iex -S mix         # interactive shell with the simulated arm
SIMULATE=1 mix run script.exs # one-off scripts against simulation
```

For tests and CI, the `SIMULATE` switch is usually unnecessary — tests that
need a running robot tend to start it explicitly with whatever opts they want
rather than relying on the application's child spec.

## When simulation is enough

Use simulation for:

- Exercising command/state-machine logic before the arm is wired up
- Visual checks of the kinematic chain (link lengths, joint axes)
- Iterating on dashboard layouts and components
- Running CI without specialised hardware

When you do have hardware, switch back by dropping the env var — the same
project boots against the real arm without any code changes.
