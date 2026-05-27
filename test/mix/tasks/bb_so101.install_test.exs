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

    test "honours a custom --device option in the generated config" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install", ["--device", "/dev/ttyACM0"])
        |> apply_igniter!()

      config =
        igniter.rewrite
        |> Rewrite.source!("config/config.exs")
        |> Rewrite.Source.get(:content)

      assert config =~ "/dev/ttyACM0"
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
      assert application =~ ~s|Application.get_env(:test, Test.Robot, [])|
    end

    test "writes the feetech device default to config/config.exs" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      config =
        igniter.rewrite
        |> Rewrite.source!("config/config.exs")
        |> Rewrite.Source.get(:content)

      assert config =~
               ~s|config :test, Test.Robot, params: [config: [feetech: [device: "/dev/ttyUSB0"]]]|
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

    test "adds arm_commands as a sparse git dep" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      mix_exs =
        igniter.rewrite
        |> Rewrite.source!("mix.exs")
        |> Rewrite.Source.get(:content)

      assert mix_exs =~ ":arm_commands"
      assert mix_exs =~ ~s|git: "https://github.com/beam-bots/bb_examples.git"|
      assert mix_exs =~ ~s|sparse: "arm_commands"|
    end
  end

  describe "arm_commands" do
    test "registers the home command with a :position argument" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      robot =
        igniter.rewrite
        |> Rewrite.source!("lib/test/robot.ex")
        |> Rewrite.Source.get(:content)

      assert robot =~ "command :home"
      assert robot =~ "BB.Examples.ArmCommands.Home"
      assert robot =~ "argument(:position"
    end

    test "registers the move_to_pose command with an :ee_link argument" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      robot =
        igniter.rewrite
        |> Rewrite.source!("lib/test/robot.ex")
        |> Rewrite.Source.get(:content)

      assert robot =~ "command :move_to_pose"
      assert robot =~ "BB.Examples.ArmCommands.MoveToPose"
      assert robot =~ "argument(:ee_link"
    end

    test "registers the demo_circle command with its plane / radius / points arguments" do
      igniter =
        test_project()
        |> Igniter.compose_task("bb_so101.install")
        |> apply_igniter!()

      robot =
        igniter.rewrite
        |> Rewrite.source!("lib/test/robot.ex")
        |> Rewrite.Source.get(:content)

      assert robot =~ "command :demo_circle"
      assert robot =~ "BB.Examples.ArmCommands.DemoCircle"
      assert robot =~ "argument(:plane, {:in, [:xy, :xz, :yz]}"
      assert robot =~ "argument(:radius, :float"
      assert robot =~ "argument(:points, :integer"
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
