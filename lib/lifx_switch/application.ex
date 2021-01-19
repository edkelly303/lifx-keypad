defmodule LifxSwitch.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LifxSwitch.Supervisor]

    children =
      [
        # LifxServer
        # Children for all targets
        # Starts a worker by calling: LifxSwitch.Worker.start_link(arg)
        # {LifxSwitch.Worker, arg},
        %{
          id: :lifx_keypad,
          start: {:keypad, :start_link, [Nil, Nil]}
        }
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: LifxSwitch.Worker.start_link(arg)
      # {LifxSwitch.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: LifxSwitch.Worker.start_link(arg)
      # {LifxSwitch.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:lifx_switch, :target)
  end
end
