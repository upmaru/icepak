defmodule Icepak.Checks.IPv6 do
  @check_name "ipv6"

  @callback perform(map) :: map

  use Icepak.Checks.Setup

  def handle_assessment(hash_item, options) do
    cluster = Keyword.fetch!(options, :cluster)
    polar_client = Keyword.fetch!(options, :polar_client)
    version = Keyword.fetch!(options, :version)
    check = Keyword.fetch!(options, :check)

    %{status: 200, body: %{"data" => assessment}} =
      @polar.get_or_create_testing_assessment(polar_client, version, %{
        check_id: check.id,
        cluster_id: cluster.id
      })

    %{status: 201, body: %{"data" => _event}} =
      @polar.transition_testing_assessment(polar_client, assessment, %{name: "run"})

    %{
      client: client,
      assessment: assessment,
      project_name: project_name,
      instance_name: instance_name
    } =
      environment = prepare(@check_name, %{hash_item: hash_item, cluster: cluster})
  end
end
