defmodule Icepak.Push do
  alias Icepak.Item
  alias Icepak.Upload

  def perform(options) do
    base_path = Path.expand(Keyword.fetch!(options, :path))

    os = Keyword.fetch!(options, :os)
    arch = Keyword.fetch!(options, :arch)
    release = Keyword.fetch!(options, :release)
    variant = Keyword.fetch!(options, :variant)
    serial = Keyword.fetch!(options, :serial)

    storage_path = Path.join(["images", os, release, arch, variant, serial])

    item_params = %{
      base_path: base_path,
      storage_path: storage_path
    }

    File.ls!(base_path)
    |> Enum.flat_map(&Item.prepare(&1, item_params))
    |> Upload.perform()
  end
end
