defmodule Icepak.Checks do
  alias Icepak.Item

  @checks_mapping %{
    "ipv4" => Icepak.Checks.IPv4,
    "ipv6" => Icepak.Checks.IPv6
  }

  @lexdee Application.compile_env(:icepak, :lexdee) || Lexdee
  @polar Application.compile_env(:icepak, :polar) || Icepak.Polar

  require Logger

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

    %{status: 201, body: %{"data" => _event}} =
      @polar.transition_version(polar_client, version, %{"name" => "test"})

    clusters = @polar.get_testing_clusters(polar_client)
    polar_checks = @polar.get_testing_checks(polar_client)

    checks =
      Enum.filter(checks, fn c ->
        c in Enum.map(polar_checks, fn pc -> pc.name end)
      end)

    assessment_events =
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
      |> Enum.reject(fn {:ok, value} -> value == :skip end)

    passes =
      Enum.filter(assessment_events, fn {:ok, %{body: %{"data" => event}}} ->
        event["name"] == "pass"
      end)

    if Enum.count(passes) == Enum.count(assessment_events) do
      Logger.info("[Checks] ✅ Activating #{product["id"]} #{version["serial"]} all checks passed")

      @polar.transition_version(polar_client, version, %{"name" => "activate"})
    else
      Logger.info(
        "[Checks] ❌ Deactivating #{product["id"]} #{version["serial"]} some checks failed"
      )

      @polar.transition_version(polar_client, version, %{"name" => "deactivate"})
    end
  end

  defp handle_metadata(metadata, state) do
    [type, _, _] = String.split(metadata.name, ".")

    cluster =
      Enum.find(state.clusters, fn c ->
        c.arch == state.arch and c.type == type
      end)

    if cluster do
      results =
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

      client =
        Lexdee.create_client(
          cluster.endpoint,
          cluster.certificate,
          cluster.private_key,
          timeout: 300_000
        )

      Enum.map(metadata.combined_hashes, &handle_cleanup(&1, client))

      results
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

  defp handle_cleanup(hash_item, client) do
    Logger.info("[Checks] Deleting image #{hash_item.hash}")

    with {:ok, %{body: delete_image}} <-
           @lexdee.delete_image(client, hash_item.hash, query: [project: "icepak-test"]),
         {:ok, _} <-
           @lexdee.wait_for_operation(client, delete_image["id"], query: [timeout: 300]) do
      :ok
    end
  end
end
