<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

`bb_so101` is a [Beam Bots](https://github.com/beam-bots/bb) package providing an
Igniter installer and operator mix tasks for the SO-101 6-DOF robot arm from
TheRobotStudio. The arm uses Feetech STS3215 serial bus servos throughout (the
printed parts only fit STS3215s), so `bb_servo_feetech` is a hard runtime dep,
not optional.

The package contains three things:

1. `Mix.Tasks.BbSo101.Install` — Igniter installer that scaffolds a complete
   SO-101 robot module into the user's project, wires up Feetech via
   `bb_servo_feetech.install`, and optionally mounts `bb_liveview`.
2. `Mix.Tasks.BbSo101.Calibrate` — interactive calibration tool for servo centre
   offsets.
3. `Mix.Tasks.BbSo101.SetupServos` — interactive wizard for assigning servo IDs
   1-6 to a fresh chain of servos.

## Build and Test Commands

```bash
mix check --no-retry          # Run all checks (compile, test, format, credo, dialyzer, reuse)
mix test                      # Run tests
mix test path/to/test.exs:42  # Run a single test at a line
mix format                    # Format code
mix credo --strict            # Linting
```

The project uses `ex_check`; prefer `mix check --no-retry` over running
individual tools.

## Architecture

### Installer composition

`bb_so101.install` composes the upstream BB installers and fills in the SO-101
topology:

1. `bb.install` — creates the base `{App}.Robot` module with stock `arm`/`disarm`
   commands and an empty `link :base_link do end`. It also generates the
   `robot_opts/0` helper in `application.ex` that branches on `SIMULATE` to boot
   in `:kinematic` simulation, so this installer no longer post-processes the
   supervision tree.
2. `BB.Igniter.populate_link/4` — fills the empty `:base_link` with the full
   SO-101 topology (6 revolute joints, visual geometry, servo IDs, calibrated
   joint limits).
3. `bb_servo_feetech.install` — adds the Feetech controller, parameter bridge,
   `:config.:feetech` param group, and the runtime device configuration. Passes
   `--name feetech_controller` to avoid a name collision with the `:feetech`
   param group.

For a LiveView dashboard, users run `mix igniter.install bb_liveview` as a
separate step after `bb_so101.install`. It's deliberately not composed because
the dashboard is optional.

### Operator tasks

`bb_so101.calibrate` and `bb_so101.setup_servos` talk to the Feetech bus
directly via the `feetech` library — they don't need the robot module to be
running. Both are interactive (`Mix.shell().prompt` / `Mix.shell().yes?`) and
designed to be run against real hardware.

## Code Map

| Path                                            | Purpose                              |
|-------------------------------------------------|--------------------------------------|
| `lib/mix/tasks/bb_so101.install.ex`             | Igniter installer + SO-101 template  |
| `lib/mix/tasks/bb_so101.setup_servos.ex`        | Interactive servo-ID wizard          |
| `lib/mix/tasks/bb_so101.calibrate.ex`           | Interactive calibration task         |
| `documentation/tutorials/01-getting-started.md` | End-to-end user tutorial             |
| `documentation/how-to/*.md`                     | Task-oriented operator references    |

The installer carries the entire SO-101 topology as a heredoc string inside
`Mix.Tasks.BbSo101.Install.so101_base_link_body/0` (`lib/mix/tasks/bb_so101.install.ex`).
That's ~370 lines of DSL — kept inline rather than read from `priv/` so the
template ships with the package and is easy to diff.

## Dependencies

- [`bb`](https://hex.pm/packages/bb) — core Beam Bots framework
- [`bb_servo_feetech`](https://hex.pm/packages/bb_servo_feetech) — Feetech servo
  integration. Hard dep, not optional: the SO-101 design only fits STS3215s.
- [`feetech`](https://hex.pm/packages/feetech) — low-level Feetech serial
  protocol, used directly by the operator mix tasks.

## Licensing headers

Every source file must carry an SPDX header — a `#`-style comment for code, an
HTML comment for Markdown, or a `<file>.license` sidecar for files that can't
hold comments (binaries, JSON, lockfiles). `mix check` runs `reuse lint` and
fails the build if one is missing.

When you create a new file, its `SPDX-FileCopyrightText` line must credit **the
user you are working for** — not you (the agent), and not this repo's original
author. Take their name from `git config user.name` (add their `user.email` if
you include one) and use the current year. Match the neighbouring files'
`SPDX-License-Identifier` (usually `Apache-2.0`):

```
SPDX-FileCopyrightText: <current year> <your user's name>

SPDX-License-Identifier: Apache-2.0
```

Never copy an existing file's copyright line onto a new file — that credits the
wrong person. When you only edit an existing file, leave its headers unchanged.
