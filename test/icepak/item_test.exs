defmodule Icepak.ItemTest do
  use ExUnit.Case, async: true

  alias Icepak.Item

  setup do
    os = "alpine"
    release = "3.20"
    arch = "arm64"
    variant = "default"
    serial = "20240527-40"

    base_path = "test/support/fixtures/arm64"
    storage_path = Path.join(["images", os, release, arch, variant, serial])

    {:ok, base_path: base_path, storage_path: storage_path}
  end

  test "can prepare item", %{base_path: base_path, storage_path: storage_path} do
    items =
      File.ls!(base_path)
      |> Enum.filter(fn file_name ->
        file_name in ["incus.tar.xz", "rootfs.squashfs", "disk.qcow2"]
      end)

    item_params = %{
      base_path: base_path,
      storage_path: storage_path
    }

    items = Enum.flat_map(items, &Item.prepare(&1, item_params))

    assert Enum.count(items) == 3

    lxd = Enum.find(items, fn i -> i.name == "lxd.tar.xz" end)

    assert lxd.size == 884
    assert lxd.hash == "05d20c16b943529d899f8da2b368d235759fa288cd96325fd690599bd98efee6"
    assert lxd.is_metadata == true
  end
end
