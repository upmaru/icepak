defmodule Icepak do
  @moduledoc """
  Documentation for `Icepak`.
  """

  defdelegate push(options),
    to: Icepak.Push
    as: :perform
end
