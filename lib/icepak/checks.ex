defmodule Icepak.Checks do
  alias Icepak.Item

  @checks_mapping %{
    "ipv4" => Icepak.Checks.IPv4,
    "ipv6" => Icepak.Checks.IPv6
  }

  @polar Application.compile_env(:icepak, :polar) || Icepak.Polar

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

    polar_client = @polar.authenticate()

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

    product_key = Enum.join([os, release, arch, variant], ":")

    %{status: 200, body: %{"data" => product}} = @polar.get_product(polar_client, product_key)
    %{status: 200, body: %{"data" => version}} = @polar.get_version(polar_client, product, serial)

    clusters = @polar.get_testing_clusters(polar_client)
    polar_checks = @polar.get_testing_checks(polar_client)

    checks =
      Enum.filter(checks, fn c ->
        c in Enum.map(polar_checks, fn pc -> pc.name end)
      end)

    items
    |> Enum.filter(fn i -> i.is_metadata end)
    |> Enum.flat_map(
      &handle_metadata(&1, %{
        arch: arch,
        checks: checks,
        polar_checks: polar_checks,
        product: product,
        version: version,
        polar_client: polar_client,
        clusters: clusters
      })
    )
  end

  defp handle_metadata(metadata, state) do
    [type, _, _] = String.split(metadata.name, ".")

    cluster =
      Enum.find(state.clusters, fn c ->
        c.arch == state.arch and c.type == type
      end)

    if cluster do
      Enum.flat_map(
        state.checks,
        &handle_check(&1, %{
          metadata: metadata,
          polar_client: state.polar_client,
          polar_checks: state.polar_checks,
          product: state.product,
          version: state.version,
          cluster: cluster
        })
      )
    else
      []
    end
  end

  defp handle_check(check, state) do
    module = Map.fetch!(@checks_mapping, check)

    polar_check =
      Enum.find(state.polar_checks, fn pc ->
        pc.name == check
      end)

    state = Map.put(state, :check, polar_check)

    module.perform(state)
  end
end
