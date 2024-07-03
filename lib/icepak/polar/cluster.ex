defmodule Icepak.Polar.Cluster do
  @derive {Inspect, only: [:id, :type, :arch, :current_state]}
  defstruct [:id, :type, :arch, :current_state, :endpoint, :private_key, :certificate]

  def new(%{
        "id" => id,
        "type" => type,
        "arch" => arch,
        "current_state" => current_state,
        "credential" => credential
      }) do
    %__MODULE__{
      id: id,
      type: type,
      arch: arch,
      current_state: current_state,
      endpoint: credential["endpoint"],
      private_key: credential["private_key"],
      certificate: credential["certificate"]
    }
  end
end
