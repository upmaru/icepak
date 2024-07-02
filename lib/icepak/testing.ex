defmodule Icepak.Testing do
  @project_params %{
    "config" => %{
      "features.networks" => "false",
      "features.profiles" => "false",
      "features.images" => "true",
      "features.storage.volumes" => "false"
    },
    "description" => "for testing built images",
    "name" => "icepak-test"
  }

  @instance_type_mappings %{
    "combined_squashfs_sha256" => "container",
    "combined_disk-kvm-img_sha256" => "vm"
  }

  @lexdee Application.compile_env(:icepak, :lexdee) || Lexdee
  # @architecture_mappings %{
  #   "amd64" => "x86_64",
  #   "arm64" => "aarch64"
  # }

  def project, do: @project_params

  def image_server do
    System.fetch_env!("TESTING_IMAGE_SERVER")
  end

  def params(attrs) do
    type = Map.fetch!(@instance_type_mappings, attrs.type)

    %{
      "ephemeral" => true,
      "type" => type,
      "architecture" => attrs.arch,
      "name" => attrs.name,
      "profiles" => ["default"],
      "source" => %{
        "type" => "image",
        "mode" => "pull",
        "protocol" => "simplestreams",
        "server" => image_server(),
        "fingerprint" => attrs.fingerprint
      }
    }
  end

  def get_or_create_project(client) do
    client
    |> @lexdee.create_project(@project_params)
    |> case do
      {:ok, _} ->
        {:ok, @project_params["name"]}

      {:error, %{"error" => error, "error_code" => 409}} = result ->
        if error =~ "entry already exists" do
          {:ok, @project_params["name"]}
        else
          result
        end

      {:error, _} ->
        {:error, :could_not_get_or_create_project}
    end
  end
end
