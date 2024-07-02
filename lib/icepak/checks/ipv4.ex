defmodule Icepak.Checks.IPv4 do
  @check_name "ipv4"

  @callback perform(map) :: map

  use Icepak.Checks.Setup

  def handle_assessment(hash_item, options) do
    cluster = Keyword.fetch!(options, :cluster)
    polar_client = Keyword.fetch!(options, :polar_client)
    version = Keyword.fetch!(options, :version)
    check = Keyword.fetch!(options, :check)
    product = Keyword.fetch!(options, :product)

    with {:ok,
          %{
            client: client,
            assessment: assessment,
            project_name: project_name,
            instance_name: instance_name
          } = environment} <-
           prepare(@check_name, %{
             polar_client: polar_client,
             version: version,
             hash_item: hash_item,
             product: product,
             cluster: cluster,
             check: check
           }) do
      {:ok, %{body: %{"network" => network}}} =
        @lexdee.get_state(client, "/1.0/instances/#{instance_name}",
          query: [project: project_name]
        )

      %{"addresses" => addresses} = Map.get(network, "eth0")
      inet = Enum.find(addresses, fn a -> a["family"] == "inet" end)

      teardown(environment)

      if not is_nil(inet) do
        Logger.info("[#{@check_name}] Passed for #{instance_name}")

        @polar.transition_testing_assessment(polar_client, assessment, %{name: "pass"})
      else
        Logger.info("[#{@check_name}] Failed for #{instance_name}")

        @polar.transition_testing_assessment(polar_client, assessment, %{name: "fail"})
      end
    else
      {:ok, :skip} ->
        :skip

      {:error, %{"error" => error}} ->
        raise CheckFailError, error
    end
  end
end
