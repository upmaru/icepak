defmodule Icepak.Push do
  alias Icepak.Item
  alias Icepak.Upload
  alias Icepak.Polar

  @architecture_mappings %{
    "alpine" => %{
      "x86_64" => "amd64",
      "aarch64" => "arm64"
    }
  }

  require Logger

  def perform(options) do
    base_path = Path.expand(Keyword.fetch!(options, :path))

    os = Keyword.fetch!(options, :os)
    arch = Keyword.fetch!(options, :arch)
    release = Keyword.fetch!(options, :release)
    variant = Keyword.fetch!(options, :variant)
    serial = Keyword.fetch!(options, :serial)

    mapping = Map.fetch!(@architecture_mappings, String.downcase(os))
    arch = Map.fetch!(mapping, arch)

    storage_path = Path.join(["images", os, release, arch, variant, serial])

    item_params = %{
      base_path: base_path,
      storage_path: storage_path
    }

    polar_client = Polar.authenticate()

    items =
      File.ls!(base_path)
      |> Enum.flat_map(&Item.prepare(&1, item_params))
      |> Upload.perform(polar_client: polar_client)

    version_params = %{
      serial: serial,
      items: items
    }

    product_key = Enum.join([os, release, arch, variant], ":")

    with %{status: 200, body: %{"data" => %{"id" => product_id, "key" => key}}} <-
           Polar.get_product(polar_client, product_key),
         %{status: 201} <- Polar.create_version(polar_client, product_id, version_params) do
      Logger.info("[Push] Sucessfully pushed version #{serial} for #{key}")
    else
      %{status: 404} ->
        Logger.error("[Push] Product not found")

      _ ->
        Logger.error("[Push] Some unknown error occurred")
    end
  end
end
