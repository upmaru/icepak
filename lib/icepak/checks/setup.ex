defmodule Icepak.Checks.Setup do
  alias Icepak.Testing

  defmacro __using__(_) do
    quote do
      import Icepak.Checks.Setup

      alias Icepak.Checks.Setup.CheckFailError

      @lexdee Application.compile_env(:icepak, :lexdee) || Lexdee
      @polar Application.compile_env(:icepak, :polar) || Icepak.Polar

      require Logger

      def perform(%{
            cluster: cluster,
            check: polar_check,
            polar_client: polar_client,
            metadata: metadata,
            version: version,
            product: product
          }) do
        options = [
          cluster: cluster,
          version: version,
          check: polar_check,
          polar_client: polar_client,
          product: product
        ]

        Task.Supervisor.async_stream(
          Icepak.TaskSupervisor,
          metadata.combined_hashes,
          __MODULE__,
          :handle_assessment,
          [options],
          timeout: 300_000
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

  @wait_time %{
    "container" => 8_000,
    "vm" => 30_000
  }

  require Logger

  def prepare(
        check_name,
        %{polar_client: polar_client, version: version, check: check, cluster: cluster} = params
      ) do
    {:ok, uuid} =
      Uniq.UUID.uuid7()
      |> ShortUUID.encode()

    requirements = Map.get(params.product, "requirements", %{})

    instance_name = Enum.join([check_name, uuid], "-")

    instance_params =
      Testing.params(%{
        type: params.hash_item.name,
        arch: params.cluster.arch,
        name: instance_name,
        fingerprint: params.hash_item.hash,
        requirements: requirements
      })

    instance_type = Map.fetch!(@instance_type_mappings, instance_params["type"])

    polar_client
    |> @polar.get_or_create_testing_assessment(version, %{
      check_id: check.id,
      cluster_id: cluster.id,
      instance_type: instance_type
    })
    |> case do
      %{status: 200, body: %{"data" => %{"current_state" => "passed"}}} ->
        Logger.info(
          "[#{check_name}] Skipping assessment #{instance_type} for #{version["serial"]} #{instance_name}"
        )

        {:ok, :skip}

      %{status: 200, body: %{"data" => %{"current_state" => _} = assessment}} ->
        Logger.info(
          "[#{check_name}] Running assessment #{instance_type} for #{version["serial"]} #{instance_name}"
        )

        %{status: 201, body: %{"data" => _event}} =
          @polar.transition_testing_assessment(polar_client, assessment, %{name: "run"})

        client =
          Lexdee.create_client(
            params.cluster.endpoint,
            params.cluster.certificate,
            params.cluster.private_key,
            timeout: 300_000
          )

        with {:ok, project_name} <- Testing.get_or_create_project(client),
             {:ok, %{body: create_operation}} <-
               @lexdee.create_instance(client, instance_params, query: [project: project_name]),
             {:ok, _wait_create_result} <-
               @lexdee.wait_for_operation(client, create_operation["id"], query: [timeout: 300]),
             {:ok, %{body: start_operation}} <-
               @lexdee.start_instance(client, instance_name, query: [project: project_name]),
             {:ok, _wait_start_result} <-
               @lexdee.wait_for_operation(client, start_operation["id"], query: [timeout: 300]) do
          if Application.get_env(:icepak, :env) != :test do
            wait_time = Map.fetch!(@wait_time, instance_type)

            Logger.info(
              "[#{check_name}] Waiting #{wait_time} ms for #{instance_type} #{instance_name}"
            )

            :timer.sleep(wait_time)
          end

          {:ok,
           %{
             client: client,
             check_name: check_name,
             assessment: assessment,
             project_name: project_name,
             instance_name: instance_name,
             instance_type: instance_type,
             fingerprint: params.hash_item.hash
           }}
        end
    end
  end

  def teardown(%{
        client: client,
        check_name: check_name,
        instance_name: instance_name,
        project_name: project_name
      }) do
    Logger.info("[#{check_name}] Deleting instance #{instance_name}")

    with {:ok, %{body: stop_operation}} <-
           @lexdee.stop_instance(client, instance_name, query: [project: project_name]),
         {:ok, _} <-
           @lexdee.wait_for_operation(client, stop_operation["id"], query: [timeout: 300]) do
      :ok
    end
  end
end
