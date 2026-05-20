# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.BbSo101.Install do
    @shortdoc "Installs an SO-101 robot definition into a project"
    @moduledoc """
    #{@shortdoc}

    Composes `bb.install` to scaffold a robot module + supervision, fills in the
    full SO-101 6-DOF topology, and wires the Feetech servo bus via
    `bb_servo_feetech.install`.

    The generated `application.ex` includes a `robot_opts/0` helper that boots
    the robot in `:kinematic` simulation mode when the `SIMULATE` environment
    variable is set, and otherwise points it at the configured serial device.

    To add a live dashboard, run `mix igniter.install bb_liveview` after this
    task.

    ## Example

    ```bash
    mix igniter.install bb_so101
    mix igniter.install bb_so101 --robot MyApp.Arm --device /dev/ttyACM0

    # Run the generated app in simulation mode (no hardware needed)
    SIMULATE=1 iex -S mix
    ```

    ## Options

      * `--robot` - Robot module name (defaults to `{AppPrefix}.Robot`)
      * `--device` - Serial device path (default `/dev/ttyUSB0`)
    """

    use Igniter.Mix.Task

    alias Igniter.Code.{Common, Function}
    alias Igniter.Project.{Deps, Formatter, Module}

    @arm_commands_dep {:arm_commands,
                       git: "https://github.com/beam-bots/bb_examples.git", sparse: "arm_commands"}

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        composes: ["bb.install", "bb_servo_feetech.install"],
        schema: [robot: :string, device: :string],
        aliases: [r: :robot]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      options = igniter.args.options
      robot_module = BB.Igniter.robot_module(igniter)
      device = Keyword.get(options, :device, "/dev/ttyUSB0")

      igniter
      |> Formatter.import_dep(:bb_so101)
      |> Igniter.compose_task("bb.install", ["--robot", inspect(robot_module)])
      |> BB.Igniter.populate_link(robot_module, [:base_link], so101_base_link_body())
      |> Igniter.compose_task("bb_servo_feetech.install", [
        "--robot",
        inspect(robot_module),
        "--device",
        device,
        # bb_servo_feetech defaults the controller to `:feetech`, which would
        # collide with its own `:feetech` param group. Use `:feetech_controller`
        # to disambiguate. The SO-101 actuator template below references it
        # by this name.
        "--name",
        "feetech_controller"
      ])
      |> lift_robot_opts_to_function(robot_module, device)
      |> add_arm_commands(robot_module)
    end

    # Adds the `arm_commands` example package (sparse git dep against
    # bb_examples) and registers its three handlers — Home, MoveToPose,
    # DemoCircle — as commands on the user's robot, with DSL argument
    # metadata so the bb_liveview dashboard renders proper input widgets
    # for each goal field.
    defp add_arm_commands(igniter, robot_module) do
      igniter
      |> Deps.add_dep(@arm_commands_dep)
      |> add_command(robot_module, :home, home_command_body())
      |> add_command(robot_module, :move_to_pose, move_to_pose_command_body())
      |> add_command(robot_module, :demo_circle, demo_circle_command_body())
    end

    # Adds a `command :name do … end` entry to the robot's `commands`
    # section. Idempotent on command name. Reuses the public
    # `Spark.Igniter.update_dsl` mechanism that BB.Igniter's own helpers
    # use; no equivalent helper exists on BB.Igniter (yet — it could be
    # promoted there in a follow-up).
    defp add_command(igniter, robot_module, name, body_code) do
      Spark.Igniter.update_dsl(igniter, robot_module, [{:section, :commands}], nil, fn zipper ->
        if command_exists?(zipper, name) do
          {:ok, zipper}
        else
          code = "command :#{name} do\n#{indent(body_code)}\nend\n"
          {:ok, Common.add_code(zipper, code)}
        end
      end)
    end

    defp command_exists?(zipper, name) do
      case Function.move_to_function_call_in_current_scope(
             zipper,
             :command,
             [2, 3],
             &Function.argument_equals?(&1, 0, name)
           ) do
        {:ok, _} -> true
        _ -> false
      end
    end

    defp indent(text) do
      text
      |> String.split("\n")
      |> Enum.map_join("\n", fn
        "" -> ""
        line -> "  " <> line
      end)
    end

    defp home_command_body do
      """
      handler(BB.Examples.ArmCommands.Home)
      allowed_states([:idle])

      argument(:position, :float, default: 0.0, doc: "Position (radians) for every movable joint")
      """
    end

    defp move_to_pose_command_body do
      """
      handler(BB.Examples.ArmCommands.MoveToPose)
      allowed_states([:idle])

      argument(:ee_link, :atom,
        default: :ee_link,
        doc: "End-effector link name in the topology"
      )
      """
    end

    defp demo_circle_command_body do
      """
      handler(BB.Examples.ArmCommands.DemoCircle)
      allowed_states([:idle])

      argument(:ee_link, :atom,
        default: :ee_link,
        doc: "End-effector link name in the topology"
      )

      argument(:plane, {:in, [:xy, :xz, :yz]},
        default: :xz,
        doc: "Plane the circle is traced in"
      )

      argument(:radius, :float, default: 0.03, doc: "Circle radius (metres)")
      argument(:points, :integer, default: 16, doc: "Number of waypoints around the circle")

      argument(:settle_tolerance_m, :float,
        default: 5.0e-3,
        doc: "EE distance from target to consider arrived (metres)"
      )

      argument(:settle_timeout_ms, :integer,
        default: 1500,
        doc: "Max wait per waypoint before continuing (milliseconds)"
      )
      """
    end

    # Replaces the inline robot child-spec opts in `application.ex` with a call
    # to `robot_opts()`, and inserts a private `robot_opts/0` function that
    # branches on `SIMULATE` env: simulation mode if set, hardware opts
    # otherwise. Matches the bb_example_so101 convention.
    defp lift_robot_opts_to_function(igniter, robot_module, device) do
      igniter
      |> replace_robot_child_opts(robot_module)
      |> add_robot_opts_function(device)
    end

    defp replace_robot_child_opts(igniter, robot_module) do
      Igniter.Project.Application.add_new_child(igniter, {robot_module, []},
        opts_updater: fn zipper ->
          {:ok, Sourceror.Zipper.replace(zipper, quote(do: robot_opts()))}
        end
      )
    end

    defp add_robot_opts_function(igniter, device) do
      app_module = application_module(igniter)
      code = robot_opts_function_code(device)

      Module.find_and_update_module!(igniter, app_module, fn zipper ->
        if robot_opts_defined?(zipper) do
          {:ok, zipper}
        else
          {:ok, Common.add_code(zipper, code)}
        end
      end)
    end

    defp robot_opts_defined?(zipper) do
      with :error <- Function.move_to_def(zipper, :robot_opts, 0),
           :error <- Function.move_to_defp(zipper, :robot_opts, 0) do
        false
      else
        {:ok, _} -> true
      end
    end

    defp application_module(igniter) do
      Elixir.Module.concat(Module.module_name_prefix(igniter), Application)
    end

    defp robot_opts_function_code(device) do
      """
      defp robot_opts do
        if System.get_env("SIMULATE") do
          [simulation: :kinematic]
        else
          [params: [config: [feetech: [device: #{inspect(device)}]]]]
        end
      end
      """
    end

    defp so101_base_link_body do
      """
      visual do
        origin do
          z(~u(0.031 meter))
        end

        cylinder do
          radius(~u(0.035 meter))
          height(~u(0.062 meter))
        end

        material do
          name(:base_dark)

          color do
            red(0.15)
            green(0.15)
            blue(0.15)
            alpha(1.0)
          end
        end
      end

      joint :shoulder_pan do
        type(:revolute)

        origin do
          z(~u(0.062 meter))
        end

        limit do
          lower(~u(-110 degree))
          upper(~u(110 degree))
          effort(~u(2.5 newton_meter))
          velocity(~u(360 degree_per_second))
          acceleration(~u(2160 degree_per_square_second))
        end

        transmission do
          reversed?(true)
        end

        actuator(
          :shoulder_pan_servo,
          {BB.Servo.Feetech.Actuator, servo_id: 1, controller: :feetech_controller}
        )

        link :shoulder_link do
          visual do
            origin do
              z(~u(0.027 meter))
            end

            box do
              x(~u(0.04 meter))
              y(~u(0.04 meter))
              z(~u(0.054 meter))
            end

            material do
              name(:servo_black)

              color do
                red(0.1)
                green(0.1)
                blue(0.1)
                alpha(1.0)
              end
            end
          end

          joint :shoulder_lift do
            type(:revolute)

            origin do
              z(~u(0.054 meter))
            end

            axis do
              roll(~u(90 degree))
            end

            limit do
              lower(~u(-10 degree))
              upper(~u(190 degree))
              effort(~u(2.5 newton_meter))
              velocity(~u(360 degree_per_second))
              acceleration(~u(2160 degree_per_square_second))
            end

            transmission do
              offset(~u(90.0 degree))
              reversed?(true)
            end

            actuator(
              :shoulder_lift_servo,
              {BB.Servo.Feetech.Actuator, servo_id: 2, controller: :feetech_controller}
            )

            link :upper_arm_link do
              visual do
                origin do
                  x(~u(0.0565 meter))
                end

                box do
                  x(~u(0.113 meter))
                  y(~u(0.03 meter))
                  z(~u(0.03 meter))
                end

                material do
                  name(:arm_white)

                  color do
                    red(0.9)
                    green(0.9)
                    blue(0.9)
                    alpha(1.0)
                  end
                end
              end

              joint :elbow_flex do
                type(:revolute)

                origin do
                  x(~u(0.113 meter))
                end

                axis do
                  roll(~u(90 degree))
                end

                limit do
                  lower(~u(-187 degree))
                  upper(~u(7 degree))
                  effort(~u(2.5 newton_meter))
                  velocity(~u(360 degree_per_second))
                  acceleration(~u(2160 degree_per_square_second))
                end

                transmission do
                  offset(~u(-90.0 degree))
                  reversed?(true)
                end

                actuator(
                  :elbow_servo,
                  {BB.Servo.Feetech.Actuator, servo_id: 3, controller: :feetech_controller}
                )

                link :forearm_link do
                  visual do
                    origin do
                      x(~u(0.0675 meter))
                    end

                    box do
                      x(~u(0.135 meter))
                      y(~u(0.025 meter))
                      z(~u(0.025 meter))
                    end

                    material do
                      name(:forearm_white)

                      color do
                        red(0.9)
                        green(0.9)
                        blue(0.9)
                        alpha(1.0)
                      end
                    end
                  end

                  joint :wrist_flex do
                    type(:revolute)

                    origin do
                      x(~u(0.135 meter))
                    end

                    axis do
                      roll(~u(90 degree))
                    end

                    limit do
                      lower(~u(-95 degree))
                      upper(~u(95 degree))
                      effort(~u(2.5 newton_meter))
                      velocity(~u(360 degree_per_second))
                      acceleration(~u(2160 degree_per_square_second))
                    end

                    transmission do
                      reversed?(true)
                    end

                    actuator(
                      :wrist_flex_servo,
                      {BB.Servo.Feetech.Actuator, servo_id: 4, controller: :feetech_controller}
                    )

                    link :wrist_link do
                      visual do
                        origin do
                          x(~u(0.0305 meter))
                        end

                        box do
                          x(~u(0.061 meter))
                          y(~u(0.025 meter))
                          z(~u(0.025 meter))
                        end

                        material do
                          name(:wrist_black)

                          color do
                            red(0.1)
                            green(0.1)
                            blue(0.1)
                            alpha(1.0)
                          end
                        end
                      end

                      joint :wrist_roll do
                        type(:revolute)

                        origin do
                          x(~u(0.061 meter))
                        end

                        axis do
                          pitch(~u(90 degree))
                        end

                        limit do
                          lower(~u(-160 degree))
                          upper(~u(160 degree))
                          effort(~u(2.5 newton_meter))
                          velocity(~u(360 degree_per_second))
                          acceleration(~u(2160 degree_per_square_second))
                        end

                        transmission do
                          reversed?(true)
                        end

                        actuator(
                          :wrist_roll_servo,
                          {BB.Servo.Feetech.Actuator, servo_id: 5, controller: :feetech_controller}
                        )

                        link :gripper_link do
                          visual do
                            origin do
                              x(~u(0.02 meter))
                            end

                            box do
                              x(~u(0.04 meter))
                              y(~u(0.04 meter))
                              z(~u(0.05 meter))
                            end

                            material do
                              name(:gripper_dark)

                              color do
                                red(0.2)
                                green(0.2)
                                blue(0.2)
                                alpha(1.0)
                              end
                            end
                          end

                          joint :gripper do
                            type(:revolute)

                            origin do
                              x(~u(0.04 meter))
                            end

                            axis do
                              roll(~u(90 degree))
                            end

                            limit do
                              lower(~u(-10 degree))
                              upper(~u(100 degree))
                              effort(~u(2.5 newton_meter))
                              velocity(~u(360 degree_per_second))
                              acceleration(~u(2160 degree_per_square_second))
                            end

                            transmission do
                              offset(~u(45.0 degree))
                            end

                            actuator(
                              :gripper_servo,
                              {BB.Servo.Feetech.Actuator,
                               servo_id: 6, controller: :feetech_controller}
                            )

                            link :jaw_link do
                              visual do
                                origin do
                                  x(~u(0.029 meter))
                                end

                                box do
                                  x(~u(0.058 meter))
                                  y(~u(0.03 meter))
                                  z(~u(0.01 meter))
                                end

                                material do
                                  name(:jaw_grey)

                                  color do
                                    red(0.4)
                                    green(0.4)
                                    blue(0.4)
                                    alpha(1.0)
                                  end
                                end
                              end

                              joint :ee_fixed do
                                type(:fixed)

                                origin do
                                  x(~u(0.058 meter))
                                end

                                link(:ee_link)
                              end
                            end
                          end

                          joint :fixed_jaw do
                            type(:fixed)

                            origin do
                              x(~u(0.04 meter))
                              z(~u(-0.010 meter))
                            end

                            link :fixed_jaw_link do
                              visual do
                                origin do
                                  x(~u(0.029 meter))
                                end

                                box do
                                  x(~u(0.058 meter))
                                  y(~u(0.03 meter))
                                  z(~u(0.01 meter))
                                end

                                material do
                                  name(:fixed_jaw_grey)

                                  color do
                                    red(0.4)
                                    green(0.4)
                                    blue(0.4)
                                    alpha(1.0)
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
      """
    end
  end
else
  defmodule Mix.Tasks.BbSo101.Install do
    @shortdoc "Installs an SO-101 robot definition into a project"
    @moduledoc false
    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The bb_so101.install task requires igniter.

          mix igniter.install bb_so101
      """)

      exit({:shutdown, 1})
    end
  end
end
