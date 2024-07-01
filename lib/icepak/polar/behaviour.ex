defmodule Icepak.Polar.Behaviour do
  alias Icepak.Polar.Cluster
  alias Icepak.Polar.Check

  @callback authenticate() :: %Req.Request{}
  @callback get_product(%Req.Request{}, String.t()) :: map()
  @callback get_version(%Req.Request{}, map, String.t()) :: map()

  @callback get_testing_clusters(%Req.Request{}) :: list(%Cluster{})
  @callback get_testing_checks(%Req.Request{}) :: list(%Check{})

  @callback get_or_create_testing_assessment(%Req.Request{}, map, map) :: map()

  @callback transition_testing_assessment(%Req.Request{}, map, map) :: map()

  @callback transition_version(%Req.Request{}, map, map) :: map()
end
