# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule Mix.Tasks.BbSo101.InstallTest do
  use ExUnit.Case
  import Igniter.Test

  @moduletag :igniter

  describe "robot module" do
    test "creates a Robot module containing the SO-101 topology" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      robot =
        igniter.rewrite
        |> Rewrite.source!("lib/test/robot.ex")
        |> Rewrite.Source.get(:content)

      assert robot =~ "joint :shoulder_pan"
      assert robot =~ "joint :shoulder_lift"
      assert robot =~ "joint :elbow_flex"
      assert robot =~ "joint :wrist_flex"
      assert robot =~ "joint :wrist_roll"
      assert robot =~ "joint :gripper"
      assert robot =~ "BB.Servo.Feetech.Actuator"
    end

    test "scaffolds the stock arm/disarm commands via bb.install" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      robot =
        igniter.rewrite
        |> Rewrite.source!("lib/test/robot.ex")
        |> Rewrite.Source.get(:content)

      assert robot =~ "command :arm"
      assert robot =~ "command :disarm"
    end

    test "respects --robot module override" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install", ["--robot", "Test.Arm"])
        |> apply_igniter!()

      assert Rewrite.has_source?(igniter.rewrite, "lib/test/arm.ex")
    end
  end

  describe "feetech wiring" do
    test "adds the feetech controller (named :feetech_controller) to the robot module" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      robot =
        igniter.rewrite
        |> Rewrite.source!("lib/test/robot.ex")
        |> Rewrite.Source.get(:content)

      assert robot =~ "controller(\n      :feetech_controller"
      assert robot =~ "BB.Servo.Feetech.Controller"
      assert robot =~ "Feetech.ControlTable.STS3215"
    end

    test "adds the feetech parameter bridge and config group" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      robot =
        igniter.rewrite
        |> Rewrite.source!("lib/test/robot.ex")
        |> Rewrite.Source.get(:content)

      assert robot =~ "bridge(:feetech_bridge"
      assert robot =~ "group :feetech"
      assert robot =~ "param(:device"
      assert robot =~ "param(:baud_rate"
    end

    test "honours a custom --device option in the generated robot_opts/0" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install", ["--device", "/dev/ttyACM0"])
        |> apply_igniter!()

      application =
        igniter.rewrite
        |> Rewrite.source!("lib/test/application.ex")
        |> Rewrite.Source.get(:content)

      assert application =~ "/dev/ttyACM0"
    end
  end

  describe "supervision tree" do
    test "registers the robot module as a supervised child" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      application =
        igniter.rewrite
        |> Rewrite.source!("lib/test/application.ex")
        |> Rewrite.Source.get(:content)

      assert application =~ "Test.Robot"
    end

    test "supervises the robot with robot_opts() rather than inline opts" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      application =
        igniter.rewrite
        |> Rewrite.source!("lib/test/application.ex")
        |> Rewrite.Source.get(:content)

      assert application =~ "{Test.Robot, robot_opts()}"
    end

    test "generates a robot_opts/0 helper with a SIMULATE env switch" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      application =
        igniter.rewrite
        |> Rewrite.source!("lib/test/application.ex")
        |> Rewrite.Source.get(:content)

      assert application =~ ~s|defp robot_opts|
      assert application =~ ~s|System.get_env("SIMULATE")|
      assert application =~ ~s|simulation: :kinematic|
      assert application =~ ~s|params: [config: [feetech: [device: "/dev/ttyUSB0"]]]|
    end
  end

  describe "deps" do
    test "does NOT explicitly add bb_servo_feetech to the user's mix.exs" do
      # bb_servo_feetech is a hard dep of bb_so101 itself, so it comes along
      # transitively. The installer must not touch the user's mix.exs deps
      # block for it.
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      mix_exs =
        igniter.rewrite
        |> Rewrite.source!("mix.exs")
        |> Rewrite.Source.get(:content)

      refute mix_exs =~ ":bb_servo_feetech"
      refute mix_exs =~ ":feetech,"
    end
  end

  describe "formatter" do
    test "imports bb_so101 into .formatter.exs" do
      test_project()
      |> Igniter.compose_task("bb_so101.install")
      |> assert_has_patch(".formatter.exs", """
      + |  import_deps: [:bb_servo_feetech, :bb, :bb_so101]
      """)
    end
  end

  describe "idempotency" do
    test "running twice produces no further changes" do
      test_project()
      |> Igniter.compose_task("bb_so101.install")
      |> apply_igniter!()
      |> Igniter.compose_task("bb_so101.install")
      |> assert_unchanged()
    end
  end
end
