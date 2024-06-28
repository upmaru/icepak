defmodule Icepak.Checks do
  alias Icepak.Polar
  alias Icepak.Item

  @checks_mapping %{
    "ipv4" => Icepak.Checks.IPv4,
    "ipv6" => Icepak.Checks.IPv6
  }

  defmodule Assessment do
    defstruct [:name, :result]
  end

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

    checks =
      Keyword.fetch!(options, :checks)
      |> String.split(",")

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

    clusters = Polar.get_testing_clusters(polar_client)

    items
    |> Enum.filter(fn i -> i.is_metadata end)
    |> Enum.flat_map(&handle_metadata(&1, %{checks: checks, clusters: clusters}))
  end

  defp handle_metadata(metadata, state) do
    [type, _, _] = String.split(metadata.name, ".")

    cluster =
      Enum.find(state.clusters, fn c ->
        c.arch == state.arch and c.type == type
      end)

    if cluster do
      Enum.flat_map(state.checks, &handle_check(&1, %{metadata: metadata, cluster: cluster}))
    else
      raise "No cluster found for arch: #{state.arch} and type: #{type}"
    end
  end

  defp handle_check(check, state) do
    module = Map.fetch!(@checks_mapping, check)

    module.perform(state)
  end
end
