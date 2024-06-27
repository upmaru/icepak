defmodule Icepak.Checks.IPv4 do
  alias Icepak.Testing

  @instance_name_prefix "ipv4"

  def perform(%{cluster: cluster, arch: arch, metadata: metadata}) do
    client =
      Lexdee.create_client(
        cluster.endpoint,
        cluster.certificate,
        cluster.private_key
      )

    Task.Supervisor.async_stream(
      Icepak.TaskSupervisor,
      metadata.combined_hashes,
      __MODULE__,
      :handle_instance,
      [client, [arch: arch]]
    )
  end

  def handle_instance(hash_item, client, options) do
    arch = Keyword.fetch!(options, :arch)

    uuid =
      Uniq.UUID.uuid7()
      |> ShortUUID.encode()

    instance_params =
      Testing.params(%{
        type: hash_item.name,
        arch: arch,
        name: Enum.join([@instance_name_prefix, uuid], "-"),
        fingerprint: hash_item.hash
      })

    with {:ok, project_name} <- Testing.get_or_create_project(client),
         {:ok, instance} <- Lexdee.create_instance(client, instance_params) do
    end
  end
end
