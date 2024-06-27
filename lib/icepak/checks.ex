defmodule Icepak.Checks do
  alias Icepak.Polar
  alias Icepak.Item

  def perform(options) do
    base_path =
      options
      |> Keyword.get(:path, System.get_env("GITHUB_WORKSPACE"))
      |> Path.expand()

    os = Keyword.fetch!(options, :os)
    arch = Keyword.fetch!(options, :arch)
    release = Keyword.fetch!(options, :release)
    variant = Keyword.fetch!(options, :variant)
    serial = Keyword.fetch!(options, :serial)

    checks = Keyword.fetch!(options, :checks)

    arch = Map.fetch!(Icepak.architecture_mappings(), arch)

    storage_path = Path.join(["images", os, release, arch, variant, serial])

    polar_client = Polar.authenticate()

    item_params = %{
      base_path: base_path,
      storage_path: storage_path
    }

    items =
      File.ls!(base_path)
      |> Enum.filter(fn file_name ->
        file_name in ["incus.tar.xz", "rootfs.squashfs", "disk.qcow2"]
      end)
      |> Enum.flat_map(&Item.prepare(&1, item_params))
  end
end
