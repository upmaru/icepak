defmodule Icepak do
  @moduledoc """
  Documentation for `Icepak`.
  """

  @architecture_mappings %{
    "x86_64" => "amd64",
    "aarch64" => "arm64",
    "arm64" => "arm64",
    "amd64" => "amd64"
  }

  def architecture_mappings, do: @architecture_mappings

  defdelegate validate(options),
    to: Icepak.Checks,
    as: :perform

  defdelegate push(options),
    to: Icepak.Push,
    as: :perform
end
