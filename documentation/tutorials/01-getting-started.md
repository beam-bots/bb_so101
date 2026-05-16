<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# Getting Started

This tutorial takes you from nothing to a running SO-101 arm with a live
LiveView dashboard. By the end you'll have:

- A new Elixir project with a `{App}.Robot` module describing the full SO-101
  kinematic chain
- Six servos with unique IDs, each calibrated so `0 rad` is the joint centre
- A Phoenix server serving the BB dashboard at `http://localhost:4000`
- A safe arm/disarm workflow and the ability to drive individual joints from
  the dashboard

If you don't have an SO-101 to hand, the
["Without hardware"](#step-2-bring-the-arm-up-without-hardware) variation at the
end of Step 2 lets you skip the wiring entirely and run the rest of the
tutorial in simulation mode.

## Prerequisites

- Elixir 1.19 or later
- The `igniter_new` archive:

  ```bash
  mix archive.install hex igniter_new
  ```

- An assembled [SO-101 arm](https://github.com/TheRobotStudio/SO-ARM100) with
  six Feetech STS3215 servos *(skip if you only want simulation mode)*
- A USB-to-TTL serial adapter (the Feetech URT-1 is a good default) connected to
  the servo daisy-chain
- A 6–7.4 V DC bench supply wired into the servo bus

## Step 1: Create the Project

Generate a new Elixir project with the SO-101 robot definition and the dashboard
preinstalled:

```bash
mix igniter.new my_arm --install bb_so101,bb_liveview
```

`igniter.new` creates the project, adds both packages as dependencies, runs each
package's installer, and asks one yes/no question along the way:

> bb_liveview needs a Phoenix application. Set up a minimal one now?

Answer **yes**. `bb_liveview` will then compose just the Phoenix sub-tasks the
dashboard needs (`core`, `endpoint`, `router`, `live`, `assets`) — without
ecto, mailer, gettext, or LiveDashboard. The whole bootstrap takes about a
minute.

When it finishes, `cd` into the project and verify it compiles:

```bash
cd my_arm
mix compile
```

You should see `lib/my_arm/robot.ex` (the full SO-101 topology),
`lib/my_arm/application.ex` (supervises the robot with a `robot_opts/0`
helper), and `lib/my_arm_web/` (the Phoenix scaffolding plus a
`bb_dashboard("/", robot: MyArm.Robot)` mount in the router).

## Step 2: Assign Servo IDs

STS3215 servos ship with a default ID of `1`. Each servo in the SO-101 needs a
unique ID matching its position in the kinematic chain:

| Joint           | Servo ID | Where it lives                |
|-----------------|----------|-------------------------------|
| `shoulder_pan`  | 1        | Base, rotates the whole arm   |
| `shoulder_lift` | 2        | Shoulder, raises/lowers       |
| `elbow_flex`    | 3        | Elbow                         |
| `wrist_flex`    | 4        | Wrist pitch                   |
| `wrist_roll`    | 5        | Wrist rotation                |
| `gripper`       | 6        | Gripper open/close            |

If the servos in your kit haven't been programmed yet, the setup wizard walks
you through them one at a time:

```bash
mix bb_so101.setup_servos /dev/ttyUSB0
```

The wizard will prompt you to **connect a single servo at a time** to the
controller. It uses a broadcast scan to find whichever servo is currently
attached, writes the correct ID to its EEPROM, asks you to disconnect it, then
repeats for the next joint. Once all six are programmed, daisy-chain them
together and reconnect to the controller.

If your `/dev/tty*` path differs (macOS often uses `/dev/tty.usbserial-…`),
pass the right device path. The default baud rate is 1 Mbaud; override with
`--baud-rate` if you've changed it on the servos.

### Bring the arm up without hardware

If you don't have an arm, skip this step and Step 3 entirely — the rest of the
tutorial works in simulation mode. Jump to [Step 4](#step-4-start-the-server)
and start the server with:

```bash
SIMULATE=1 mix phx.server
```

The robot module is identical; what changes is that the Feetech controller is
omitted from the supervision tree and the actuators are replaced with
`BB.Sim.Actuator`, which publishes simulated motion. Forward kinematics still
work, so the dashboard's 3D view and joint sliders both behave the same way as
with a real arm.

## Step 3: Calibrate the Arm

The kinematic limits in `lib/my_arm/robot.ex` are expressed in radians around
**each joint's mechanical centre**. Calibration writes a position offset into
each servo's EEPROM so the servo agrees with that convention. Without it, the
3D model and the physical arm will be visibly out of sync.

With all six servos daisy-chained and powered on:

```bash
mix bb_so101.calibrate /dev/ttyUSB0
```

The task:

1. Disables torque on every servo so you can move the arm freely with your
   hands.
2. Continuously reads each joint's position and shows live min / max
   tracking.
3. Asks you to **move every joint through its full range of motion** — bend
   each one to both mechanical limits, including opening and closing the
   gripper.
4. When you press Enter, it computes the mid-point of each joint's observed
   range, converts that to a position offset, and writes it to the servo.

If you want to see the offsets before they're written, run it with
`--dry-run` (or `-n`) first.

Calibration only needs to happen once per arm — the offsets are stored in
EEPROM and persist across power cycles. Re-run it if you ever remount a horn
or replace a servo. See the
[Calibrate the Arm](../how-to/calibrate-servos.md) how-to guide for the full
option reference.

## Step 4: Start the Server

```bash
mix phx.server
```

The first start fetches and builds assets (esbuild, Tailwind, etc.); subsequent
starts are fast. When you see:

```
[info] Running MyArmWeb.Endpoint with Bandit ... at 127.0.0.1:4000 (http)
```

you're ready to drive the arm.

If you're running without hardware, prefix it with `SIMULATE=1`:

```bash
SIMULATE=1 mix phx.server
```

## Step 5: Drive the Arm From the Dashboard

Open <http://localhost:4000> in a browser. You should see:

- **Robot** — the title bar, with a green "Connected" indicator on the right
- **Safety** — current state (Disarmed) plus **Arm** and **Disarm** buttons
- **Commands** — tabs for `arm` and `disarm`, each with an **Execute** button
- **3D Visualisation** — a Three.js view of the arm, in its current pose
- **Joint Control** — a table of all six revolute joints, each with a position
  readout and a target slider
- **Event Stream** — the live PubSub message feed
- **Parameters** — the `feetech` config group (the serial device and baud rate)

The robot starts in the **Disarmed** state. In this state the joint sliders are
read-only and no command will move the arm — Beam Bots' safety system requires
explicit arming before motion is allowed.

### Arm the robot

Click **Arm** in the Safety panel, or run the `arm` command from the Commands
panel. The Safety indicator turns green and reads **Idle**. The joint sliders
become interactive.

### Move a joint

In the Joint Control panel, drag the **Target** slider for any joint. As you
release, the dashboard publishes a position command:

- With real hardware, the corresponding Feetech servo rotates to the requested
  position. The 3D view and the **Position** column update from the servo's
  feedback messages.
- In simulation, `BB.Sim.Actuator` publishes synthetic motion events and the
  forward-kinematics layer updates the 3D view from the simulated joint state.

The **Event Stream** panel below shows every PubSub message — joint state
updates, command lifecycle events, parameter changes. Useful when you're
debugging unexpected behaviour.

### Disarm

Click **Disarm** (or send the `disarm` command). Safety state returns to
**Disarmed**. On real hardware this disables torque on every servo so the arm
goes limp; if it was holding a position above gravity, support it before
disarming.

## Where Next?

You now have the full bring-up loop. From here:

- **Define custom commands.** The `arm` and `disarm` commands are the built-in
  state-machine commands. Domain-specific commands (move-to-home,
  pick-and-place, sweep-through-positions) live in your own modules — see the
  [Commands and State Machine](https://hexdocs.pm/bb/05-commands.html) tutorial
  in the core `bb` framework for the patterns.
- **Tune motion via parameters.** The `bb_servo_feetech` parameter bridge
  exposes every register in the servo control table — position gains, max
  speed, torque limit. The Parameters panel of the dashboard reads and writes
  them at runtime.
- **Subscribe to the robot's PubSub topics** from your own code (logging,
  alarms, derived sensors). The
  [Sensors and PubSub](https://hexdocs.pm/bb/03-sensors-and-pubsub.html)
  tutorial covers the topic tree.

When you're ready to deploy to embedded hardware, the
[Deploy to Nerves](https://hexdocs.pm/bb/deploy-to-nerves.html) guide in the
`bb` docs has the production checklist.
