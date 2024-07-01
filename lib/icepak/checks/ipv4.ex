defmodule Icepak.Checks.IPv4 do
  alias Icepak.Testing

  @check_name "ipv4"

  @lexdee Application.compile_env(:icepak, :lexdee) || Lexdee
  @polar Application.compile_env(:icepak, :polar) || Icepak.Polar

  @callback perform(map) :: map

  def perform(%{
        cluster: cluster,
        check: polar_check,
        polar_client: polar_client,
        metadata: metadata,
        version: version
      }) do
    options = [
      cluster: cluster,
      version: version,
      check: polar_check,
      polar_client: polar_client
    ]

    Task.Supervisor.async_stream(
      Icepak.TaskSupervisor,
      metadata.combined_hashes,
      __MODULE__,
      :handle_assessment,
      [options],
      timeout: 30_000
    )
    |> Enum.to_list()
  end

  def handle_assessment(hash_item, options) do
    cluster = Keyword.fetch!(options, :cluster)
    polar_client = Keyword.fetch!(options, :polar_client)
    version = Keyword.fetch!(options, :version)
    check = Keyword.fetch!(options, :check)

    client =
      Lexdee.create_client(
        cluster.endpoint,
        cluster.certificate,
        cluster.private_key
      )

    %{status: 200, body: %{"data" => assessment}} =
      @polar.get_or_create_testing_assessment(polar_client, version, %{
        check_id: check.id,
        cluster_id: cluster.id
      })

    %{status: 201, body: %{"data" => _event}} =
      @polar.transition_testing_assessment(polar_client, assessment, %{name: "run"})

    {:ok, uuid} =
      Uniq.UUID.uuid7()
      |> ShortUUID.encode()

    instance_name = Enum.join([@check_name, uuid], "-")

    instance_params =
      Testing.params(%{
        type: hash_item.name,
        arch: cluster.arch,
        name: instance_name,
        fingerprint: hash_item.hash
      })

    with {:ok, project_name} <- Testing.get_or_create_project(client),
         {:ok, %{body: create_operation}} <-
           @lexdee.create_instance(client, instance_params, query: [project: project_name]),
         {:ok, _wait_create_result} <-
           @lexdee.wait_for_operation(client, create_operation["id"], query: [timeout: 120]),
         {:ok, %{body: start_operation}} <-
           @lexdee.start_instance(client, instance_name, query: [project: project_name]),
         {:ok, _wait_start_result} <-
           @lexdee.wait_for_operation(client, start_operation["id"], query: [timeout: 120]) do
      :timer.sleep(2_000)

      {:ok, %{body: %{"network" => network}}} =
        @lexdee.get_state(client, "/1.0/instances/#{instance_name}",
          query: [project: project_name]
        )

      %{"addresses" => addresses} = Map.get(network, "eth0")
      inet = Enum.find(addresses, fn a -> a["family"] == "inet" end)

      if not is_nil(inet) do
        @polar.transition_testing_assessment(polar_client, assessment, %{name: "pass"})
      else
        @polar.transition_testing_assessment(polar_client, assessment, %{name: "fail"})
      end
    end
  end
end
