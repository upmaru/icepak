defmodule Icepak.Polar.Cluster do
  @derive {Inspect, only: [:id, :type, :arch, :current_state, :instance_wait_times]}
  defstruct [
    :id,
    :type,
    :arch,
    :current_state,
    :endpoint,
    :private_key,
    :certificate,
    :instance_wait_times
  ]

  def new(%{
        "id" => id,
        "type" => type,
        "arch" => arch,
        "current_state" => current_state,
        "credential" => credential,
        "instance_wait_times" => instance_wait_times
      }) do
    %__MODULE__{
      id: id,
      type: type,
      arch: arch,
      current_state: current_state,
      endpoint: credential["endpoint"],
      private_key: credential["private_key"],
      certificate: credential["certificate"],
      instance_wait_times: instance_wait_times
    }
  end
end
