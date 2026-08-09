# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule Mix.Tasks.BbSo101.UpgradeTest do
  use ExUnit.Case
  import Igniter.Test

  @moduletag :igniter

  defp robot_with(limits, actuator) do
    """
    defmodule Test.Robot do
      use BB

      topology do
        link :base do
          joint :shoulder do
            type(:revolute)

            limit do
              lower(~u(-110 degree))
              upper(~u(110 degree))
    #{limits}
            end

            #{actuator}

            link :arm do
            end
          end
        end
      end
    end
    """
  end

  defp upgrade(source) do
    test_project(files: %{"lib/test/robot.ex" => source})
    |> Igniter.compose_task("bb_so101.upgrade")
    |> apply_igniter!()
    |> then(&Rewrite.source!(&1.rewrite, "lib/test/robot.ex"))
    |> Rewrite.Source.get(:content)
  end

  @feetech "actuator :servo, {BB.Servo.Feetech.Actuator, servo_id: 1, controller: :bus}"
  @other "actuator :servo, {Some.Other.Actuator, pin: 1}"

  describe "limits beyond the hardware" do
    test "an unreachable acceleration is brought back inside the register" do
      result =
        upgrade(
          robot_with(
            """
                  velocity(~u(333 degree_per_second))
                  acceleration(~u(2160 degree_per_square_second))
            """,
            @feetech
          )
        )

      assert result =~ "acceleration(~u(400 degree_per_square_second))"
      refute result =~ "2160"
    end

    test "an unreachable velocity comes down to what the servo manages" do
      result =
        upgrade(
          robot_with(
            """
                  velocity(~u(360 degree_per_second))
                  acceleration(~u(400 degree_per_square_second))
            """,
            @feetech
          )
        )

      assert result =~ "velocity(~u(300 degree_per_second))"
      refute result =~ "360 degree_per_second"
    end
  end

  describe "what it leaves alone" do
    test "limits already within reach are untouched" do
      result =
        upgrade(
          robot_with(
            """
                  velocity(~u(120 degree_per_second))
                  acceleration(~u(90 degree_per_square_second))
            """,
            @feetech
          )
        )

      assert result =~ "velocity(~u(120 degree_per_second))"
      assert result =~ "acceleration(~u(90 degree_per_square_second))"
    end

    test "a joint driven by another servo family keeps its limits" do
      # these ceilings are one family's; a mixed robot must survive this
      result =
        upgrade(
          robot_with(
            """
                  velocity(~u(2000 degree_per_second))
                  acceleration(~u(9000 degree_per_square_second))
            """,
            @other
          )
        )

      assert result =~ "velocity(~u(2000 degree_per_second))"
      assert result =~ "acceleration(~u(9000 degree_per_square_second))"
    end

    test "position limits are not rates and are never rewritten" do
      result =
        upgrade(
          robot_with(
            """
                  velocity(~u(333 degree_per_second))
            """,
            @feetech
          )
        )

      assert result =~ "lower(~u(-110 degree))"
      assert result =~ "upper(~u(110 degree))"
    end

    test "units it cannot reason about are left as written" do
      result =
        upgrade(
          robot_with(
            """
                  velocity(~u(40 radian_per_second))
            """,
            @feetech
          )
        )

      assert result =~ "velocity(~u(40 radian_per_second))"
    end
  end

  test "running it twice changes nothing the second time" do
    once =
      upgrade(
        robot_with(
          """
                velocity(~u(333 degree_per_second))
                acceleration(~u(2160 degree_per_square_second))
          """,
          @feetech
        )
      )

    twice =
      test_project(files: %{"lib/test/robot.ex" => once})
      |> Igniter.compose_task("bb_so101.upgrade")
      |> apply_igniter!()
      |> then(&Rewrite.source!(&1.rewrite, "lib/test/robot.ex"))
      |> Rewrite.Source.get(:content)

    assert once == twice
  end

  test "an older generated robot is brought up to date" do
    # what the installer emitted before this version
    generated =
      test_project()
      |> Igniter.compose_task("bb_so101.install")
      |> apply_igniter!()
      |> then(&Rewrite.source!(&1.rewrite, "lib/test/robot.ex"))
      |> Rewrite.Source.get(:content)

    stale =
      generated
      |> String.replace(
        "velocity(~u(300 degree_per_second))",
        "velocity(~u(360 degree_per_second))"
      )
      |> String.replace(
        "acceleration(~u(400 degree_per_square_second))",
        "acceleration(~u(2160 degree_per_square_second))"
      )

    assert stale =~ "2160"

    upgraded =
      test_project(files: %{"lib/test/robot.ex" => stale})
      |> Igniter.compose_task("bb_so101.upgrade")
      |> apply_igniter!()
      |> then(&Rewrite.source!(&1.rewrite, "lib/test/robot.ex"))
      |> Rewrite.Source.get(:content)

    refute upgraded =~ "2160"
    refute upgraded =~ "360 degree_per_second"
    assert length(Regex.scan(~r/velocity\(~u\(300 degree_per_second\)\)/, upgraded)) == 6

    assert length(Regex.scan(~r/acceleration\(~u\(400 degree_per_square_second\)\)/, upgraded)) ==
             6
  end
end
