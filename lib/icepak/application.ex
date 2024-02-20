defmodule Icepak.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @cacerts CAStore.file_path()
           |> File.read!()
           |> :public_key.pem_decode()
           |> Enum.map(fn {_, cert, _} -> cert end)

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, finch_options(Application.get_env(:icepak, :env))}
      # Starts a worker by calling: Icepak.Worker.start_link(arg)
      # {Icepak.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Icepak.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp finch_options(env) when env in [:test, :dev], do: [name: Icepak.Finch]

  defp finch_options(_) do
    [
      name: Icepak.Finch,
      pools: %{
        default: [
          size: 10,
          conn_opts: [
            transport_opts: [
              verify: :verify_peer,
              cacerts: @cacerts
            ]
          ]
        ]
      }
    ]
  end
end
