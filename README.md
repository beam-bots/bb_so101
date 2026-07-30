<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

<img src="https://github.com/beam-bots/bb/blob/main/logos/beam_bots_logo.png?raw=true" alt="Beam Bots Logo" width="250" />

# BB SO-101

[![CI](https://github.com/beam-bots/bb_so101/actions/workflows/ci.yml/badge.svg)](https://github.com/beam-bots/bb_so101/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache--2.0-green.svg)](https://opensource.org/licenses/Apache-2.0)
[![Hex version badge](https://img.shields.io/hexpm/v/bb_so101.svg)](https://hex.pm/packages/bb_so101)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/bb_so101)
[![REUSE status](https://api.reuse.software/badge/github.com/beam-bots/bb_so101)](https://api.reuse.software/info/github.com/beam-bots/bb_so101)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/beam-bots/bb_so101)

[Beam Bots](https://github.com/beam-bots/bb) installer and operator tools for
TheRobotStudio's [SO-101](https://github.com/TheRobotStudio/SO-ARM100) — a 6-DOF
desktop robot arm built around Feetech STS3215 serial bus servos.

## Features

- **Single-command bootstrap** — `mix igniter.install bb_so101` scaffolds a complete robot module, supervisor wiring, and `SIMULATE`-aware boot options
- **Full SO-101 topology** — kinematic chain matches the official URDF; six revolute joints with calibrated limits and visual geometry
- **Feetech wiring out of the box** — composes [`bb_servo_feetech.install`](https://hex.pm/packages/bb_servo_feetech) to set up controller, parameter bridge, and serial port config
- **Operator mix tasks** — interactive wizards for assigning servo IDs and calibrating mechanical zeroes
- **Hardware-free development** — run the generated project in simulation mode with `SIMULATE=1`

## Installation

In an existing project:

```bash
mix igniter.install bb_so101
```

Or scaffold a new project with the dashboard included:

```bash
mix igniter.new my_robot --install bb_so101,bb_liveview
```

The [Getting Started tutorial](https://hexdocs.pm/bb_so101/01-getting-started.html)
walks the rest of the way through powering up the arm, setting servo IDs,
calibrating, and driving the dashboard.

## Installer Options

| Option     | Default         | Description                                |
|------------|-----------------|--------------------------------------------|
| `--robot`  | `{App}.Robot`   | Module name for the generated robot module |
| `--device` | `/dev/ttyUSB0`  | Fallback serial device path                |

The generated `config/runtime.exs` reads the device path from `FEETECH_DEVICE`,
falling back to `--device`. The generated `application.ex` boots the robot in
`:kinematic` simulation mode when `SIMULATE=1` is set in the environment.

## Operator Tasks

Once your project is generated and your servos are wired, two mix tasks help
you bring the arm up:

```bash
# One-time: assign servo IDs 1-6 to each servo in turn
mix bb_so101.setup_servos /dev/ttyUSB0

# Per-arm: write mechanical-zero offsets so `0 rad` is the joint centre
mix bb_so101.calibrate /dev/ttyUSB0
```

See the [Set Up Servo IDs](https://hexdocs.pm/bb_so101/setup-servo-ids.html) and
[Calibrate the Arm](https://hexdocs.pm/bb_so101/calibrate-servos.html) how-to
guides for detail.

## Requirements

- Elixir ~> 1.19
- An [SO-101 arm](https://github.com/TheRobotStudio/SO-ARM100) (or run in simulation mode)
- A USB-to-TTL serial adapter (Feetech URT-1 or compatible) for hardware mode
- 6–7.4 V DC power for the servos

## Documentation

### Tutorials

- [Getting Started](https://hexdocs.pm/bb_so101/01-getting-started.html) —
  bootstrap a project, set servo IDs, calibrate, and drive the dashboard

### How-to Guides

- [Set Up Servo IDs](https://hexdocs.pm/bb_so101/setup-servo-ids.html)
- [Calibrate the Arm](https://hexdocs.pm/bb_so101/calibrate-servos.html)
- [Run in Simulation](https://hexdocs.pm/bb_so101/run-in-simulation.html)

Full API documentation is available at [HexDocs](https://hexdocs.pm/bb_so101).

## Related Packages

- [`bb`](https://github.com/beam-bots/bb) — core Beam Bots framework
- [`bb_liveview`](https://github.com/beam-bots/bb_liveview) — Phoenix LiveView dashboard
- [`bb_servo_feetech`](https://github.com/beam-bots/bb_servo_feetech) — Feetech STS servo driver
- [`feetech`](https://github.com/beam-bots/feetech) — Feetech serial protocol library

## Acknowledgements

- [TheRobotStudio](https://github.com/TheRobotStudio) for the SO-ARM100 open-source design and reference URDF
- [Feetech](https://www.feetechrc.com/) for the STS series servos
