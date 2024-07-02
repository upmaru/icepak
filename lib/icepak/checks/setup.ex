defmodule Icepak.Checks.Setup do
  alias Icepak.Testing

  defmacro __using__(_) do
    quote do
      import Icepak.Checks.Setup

      alias Icepak.Checks.Setup.CheckFailError

      @lexdee Application.compile_env(:icepak, :lexdee) || Lexdee
      @polar Application.compile_env(:icepak, :polar) || Icepak.Polar

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
          timeout: 60_000
        )
        |> Enum.to_list()
      end
    end
  end

  defmodule CheckFailError do
    defexception [:message]
  end

  @lexdee Application.compile_env(:icepak, :lexdee) || Lexdee
  @polar Application.compile_env(:icepak, :polar) || Icepak.Polar

  @instance_type_mappings %{
    "container" => "container",
    "virtual-machine" => "vm"
  }

  def prepare(
        check_name,
        %{polar_client: polar_client, version: version, check: check, cluster: cluster} = params
      ) do
    {:ok, uuid} =
      Uniq.UUID.uuid7()
      |> ShortUUID.encode()

    instance_name = Enum.join([check_name, uuid], "-")

    instance_params =
      Testing.params(%{
        type: params.hash_item.name,
        arch: params.cluster.arch,
        name: instance_name,
        fingerprint: params.hash_item.hash
      })

    %{status: 200, body: %{"data" => assessment}} =
      @polar.get_or_create_testing_assessment(polar_client, version, %{
        check_id: check.id,
        cluster_id: cluster.id,
        instance_type: Map.fetch!(@instance_type_mappings, instance_params["type"])
      })

    %{status: 201, body: %{"data" => _event}} =
      @polar.transition_testing_assessment(polar_client, assessment, %{name: "run"})

    client =
      Lexdee.create_client(
        params.cluster.endpoint,
        params.cluster.certificate,
        params.cluster.private_key
      )

    with {:ok, project_name} <- Testing.get_or_create_project(client),
         {:ok, %{body: create_operation}} <-
           @lexdee.create_instance(client, instance_params, query: [project: project_name]),
         {:ok, _wait_create_result} <-
           @lexdee.wait_for_operation(client, create_operation["id"], query: [timeout: 120]),
         {:ok, %{body: start_operation}} <-
           @lexdee.start_instance(client, instance_name, query: [project: project_name]),
         {:ok, _wait_start_result} <-
           @lexdee.wait_for_operation(client, start_operation["id"], query: [timeout: 120]) do
      if Application.get_env(:icepak, :env) != :test do
        :timer.sleep(2_000)
      end

      {:ok,
       %{
         client: client,
         assessment: assessment,
         project_name: project_name,
         instance_name: instance_name
       }}
    end
  end

  def teardown(%{client: client, instance_name: instance_name, project_name: project_name}) do
    with {:ok, %{body: stop_operation}} <-
           @lexdee.stop_instance(client, instance_name, query: [project: project_name]),
         {:ok, _} <-
           @lexdee.wait_for_operation(client, stop_operation["id"], query: [timeout: 120]) do
      :ok
    end
  end
end
