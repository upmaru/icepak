defmodule Icepak.Push do
  alias Icepak.Item
  alias Icepak.Upload
  alias Icepak.Polar

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

    arch = Map.fetch!(Icepak.architecture_mappings(), arch)

    storage_path = Path.join(["images", os, release, arch, variant, serial])

    item_params = %{
      base_path: base_path,
      storage_path: storage_path
    }

    polar_client = Polar.authenticate()

    items =
      File.ls!(base_path)
      |> Enum.filter(fn file_name ->
        file_name in ["incus.tar.xz", "rootfs.squashfs", "disk.qcow2"]
      end)
      |> Enum.flat_map(&Item.prepare(&1, item_params))
      |> Upload.perform(polar_client: polar_client)

    version_params = %{
      serial: serial,
      items: items
    }

    product_key = Enum.join([os, release, arch, variant], ":")

    with %{status: 200, body: %{"data" => %{"id" => product_id, "key" => key}}} <-
           Polar.get_product(polar_client, product_key),
         %{status: 201, body: %{"data" => version}} <-
           Polar.create_version(polar_client, product_id, version_params),
         %{status: 201} <- Polar.transition_version(polar_client, version, %{"name" => "test"}) do
      Logger.info("[Push] Sucessfully pushed version #{serial} for #{key}")
    else
      %{status: 404} ->
        Logger.error("[Push] Product not found.")

        raise "[Push] Product not found please create make sure the product with key #{product_key} exists on polar image server."

      _ ->
        Logger.error("[Push] Some unknown error occurred.")

        raise "[Push] Some unknown error occurred."
    end
  end
end
