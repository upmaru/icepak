defmodule Icepak.Polar.Check do
  defstruct [:id, :name]

  def new(%{"id" => id, "slug" => name}) do
    %__MODULE__{
      id: id,
      name: name
    }
  end
end
