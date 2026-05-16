<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# Set Up Servo IDs

`mix bb_so101.setup_servos PORT` is an interactive wizard that assigns the six
SO-101 servo IDs in turn. Use it the first time you wire up an arm, or any time
you replace a servo.

## Usage

```bash
mix bb_so101.setup_servos /dev/ttyUSB0
mix bb_so101.setup_servos /dev/ttyACM0 --baud-rate 500000
```

| Argument         | Default        | Description                            |
|------------------|----------------|----------------------------------------|
| `PORT`           | required       | Serial port for the Feetech bus        |
| `--baud-rate`    | `1000000`      | Servo bus baud rate                    |
| `-b`             | alias          | Short form of `--baud-rate`            |

## How it works

The wizard processes one joint at a time, in this order:

1. `shoulder_pan` → ID 1
2. `shoulder_lift` → ID 2
3. `elbow_flex` → ID 3
4. `wrist_flex` → ID 4
5. `wrist_roll` → ID 5
6. `gripper` → ID 6

For each joint the wizard:

1. Asks you to **connect a single servo** to the controller (disconnect all
   others).
2. Broadcasts a discovery query and reports the ID of whatever servo it
   finds.
3. Asks you to confirm, then writes the target ID to the servo's EEPROM and
   verifies by re-reading it back.
4. Prompts you to disconnect that servo before continuing to the next.

Once all six are programmed, daisy-chain them back together and reconnect to
the controller.

## Common adjustments

### Servo already has the right ID

Skip it. The wizard's "skip" option leaves the servo unchanged and moves on.

### One servo of a known ID

If you only need to re-program one servo (e.g. a replacement gripper servo),
connect it alone, run the wizard, and skip the joints whose servos are already
correct.

### A custom baud rate

If you've changed the bus speed away from the 1 Mbaud default (e.g. via the
Parameters panel of the dashboard), pass `--baud-rate` so the wizard can talk
to the servo:

```bash
mix bb_so101.setup_servos /dev/ttyUSB0 --baud-rate 500000
```

## Troubleshooting

### "No servo found on the bus"

- Check that **only one** servo is connected — the wizard scans by broadcast,
  so multiple servos will all reply and confuse the discovery step.
- Confirm the serial adapter shows up as the path you passed
  (`ls /dev/ttyUSB*` or `ls /dev/ttyACM*`).
- Verify the servo has power and is fully wired (TX/RX swapped is the usual
  cause).

### "ID write failed verification"

The write happens but the read-back doesn't match. Usually a flaky cable or
brown-out on the power supply during the write. Retry; if it persists, the
servo's EEPROM may be locked — power-cycle the bus and try again.

## Next: calibrate

Once IDs are assigned, [calibrate the arm](calibrate-servos.md) so that each
joint's mechanical centre maps to `0 rad`.
