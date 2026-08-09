# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule Mix.Tasks.BbSo101.CalibrateTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.BbSo101.Calibrate

  defp sweep(min, max), do: %{min_unwrapped: min, max_unwrapped: max}

  describe "zero_point/2" do
    test "a symmetric joint takes the midpoint of its travel" do
      assert {1422, description} = Calibrate.zero_point(:shoulder_pan, sweep(674, 2170))
      assert description =~ "midpoint"
    end

    test "the midpoint splits under-travel across both ends" do
      # 100 steps short at the top moves the zero by only half that
      {full, _} = Calibrate.zero_point(:wrist_flex, sweep(674, 2170))
      {short, _} = Calibrate.zero_point(:wrist_flex, sweep(674, 2070))
      assert full - short == 50
    end

    test "the gripper anchors 10 degrees above its closed stop" do
      # 10° is 113.8 steps of a 4096-step revolution
      assert {788, description} = Calibrate.zero_point(:gripper, sweep(674, 2170))
      assert description =~ "above the lower stop"
    end

    test "the gripper ignores where the open end lands" do
      {a, _} = Calibrate.zero_point(:gripper, sweep(674, 2170))
      {b, _} = Calibrate.zero_point(:gripper, sweep(674, 1800))
      assert a == b
    end

    test "the gripper moves with its closed stop" do
      {a, _} = Calibrate.zero_point(:gripper, sweep(674, 2170))
      {b, _} = Calibrate.zero_point(:gripper, sweep(774, 2170))
      assert b - a == 100
    end

    test "the measured arm yields the expected offset" do
      # Recorded on an SO-101: gripper sweeps 674..2170 raw.
      {zero, _} = Calibrate.zero_point(:gripper, sweep(674, 2170))
      assert zero - 2048 == -1260
    end
  end
end
