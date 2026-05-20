<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# Calibrate the Arm

`mix bb_so101.calibrate PORT` writes a position offset to each servo so that
the joint's mechanical centre corresponds to `0 rad` in the BB DSL. Run it
after assigning IDs, and any time you remount a servo horn or replace a servo.

## Usage

```bash
mix bb_so101.calibrate /dev/ttyUSB0
mix bb_so101.calibrate /dev/ttyUSB0 --dry-run
mix bb_so101.calibrate /dev/ttyACM0 --baud-rate 500000
```

| Argument         | Default        | Description                                      |
|------------------|----------------|--------------------------------------------------|
| `PORT`           | required       | Serial port for the Feetech bus                  |
| `--dry-run` / `-n` | _off_        | Compute and display offsets without writing      |
| `--baud-rate` / `-b` | `1000000`  | Servo bus baud rate                              |

## How it works

1. **Torque is disabled** on every servo so the arm can be moved freely.
2. The task polls all six servos in a loop and updates a live display of the
   min/max raw position observed for each joint.
3. You move **every joint through its full mechanical range** — both extremes
   for each revolute joint, all the way open and all the way closed for the
   gripper. Don't be subtle; push to the actual mechanical limits.
4. Press Enter when you're done.
5. For each joint, the task computes the midpoint of the observed range,
   converts it to the servo's signed-magnitude offset format, and writes it to
   EEPROM. The new offset takes effect immediately.

Why this is needed: STS3215 servos have a 4096-step rotation and a factory
default that puts step 2048 at the centre of rotation. But "the centre of
rotation" doesn't necessarily coincide with the joint's mechanical centre —
horns get pressed on at whatever angle they happened to be at. The offset
shifts the servo's reported position so the mechanical centre reads as 2048
(and therefore `0 rad` after BB's mapping).

## Common adjustments

### Preview before writing

Pass `--dry-run` (or `-n`) to see the computed offsets without touching
EEPROM. Useful as a sanity check, or when troubleshooting unexpected joint
behaviour.

```bash
mix bb_so101.calibrate /dev/ttyUSB0 --dry-run
```

### Re-calibrating one joint

The task always reads min/max for all six joints. There's no per-joint flag.
The simplest workaround is to manually drive only the joint you care about
through its range and leave the others stationary — the offsets for the
untouched joints will be `±0`, which is a no-op.

### Different baud rate

Match whatever's currently on the bus:

```bash
mix bb_so101.calibrate /dev/ttyUSB0 --baud-rate 500000
```

## Troubleshooting

### One joint reports a tiny range

You didn't move it far enough. The min/max readout is live — exercise that
joint to both stops before pressing Enter.

### Calibration "works" but the 3D model is still off

The offsets only correct *mechanical* misalignment. If the URDF in
`bb_so101`'s topology doesn't match your specific arm (e.g. you swapped a
3D-printed bracket), no amount of calibration will reconcile that. Inspect
the generated `lib/{App}/robot.ex` and adjust link lengths or joint axes
manually.

### The gripper feels backwards

The gripper actuator uses the joint's positive direction, which on a standard
SO-101 means "open". If your gripper closes when commanded to open, add a
`reversed? true` line to the gripper joint's `transmission` block in the
generated `robot.ex`:

```elixir
joint :gripper do
  # ...
  transmission do
    offset(~u(45.0 degree))
    reversed?(true)
  end

  actuator(
    :gripper_servo,
    {BB.Servo.Feetech.Actuator, servo_id: 6, controller: :feetech_controller}
  )
end
```

The other five joints have `reversed? true` baked into their transmission
already; the gripper historically doesn't need it but kits vary.

## When you _don't_ need to recalibrate

- After a normal power cycle — offsets are stored in EEPROM and persist.
- After a `mix bb_so101.calibrate` itself — only run it again if something
  changed mechanically.
- After updating `bb_so101` to a new version — the offsets are per-servo, not
  per-package version.
