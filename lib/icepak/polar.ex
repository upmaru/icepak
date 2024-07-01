defmodule Icepak.Polar do
  require Logger

  @behaviour Icepak.Polar.Behaviour

  def get_product(client, key) do
    key = Base.url_encode64(key)

    Req.get!(client, url: "/publish/products/#{key}")
  end

  def get_version(client, product, serial) do
    product_id = product["id"]

    Req.get!(client, url: "/publish/products/#{product_id}/versions/#{serial}")
  end

  def create_version(client, product_id, version_params) do
    Req.post!(client,
      url: "/publish/products/#{product_id}/versions",
      json: %{version: version_params}
    )
  end

  def get_storage(client) do
    Req.get!(client, url: "/publish/storage")
  end

  def get_testing_checks(client) do
    Req.get!(client, url: "/publish/testing/checks")
    |> case do
      %{status: 200, body: %{"data" => checks}} ->
        Enum.map(checks, fn check ->
          __MODULE__.Check.new(check)
        end)

      _ ->
        raise "Failed to fetch testing checks"
    end
  end

  def get_testing_clusters(client) do
    Req.get!(client, url: "/publish/testing/clusters")
    |> case do
      %{status: 200, body: %{"data" => clusters}} ->
        Enum.map(clusters, fn cluster ->
          __MODULE__.Cluster.new(cluster)
        end)

      _ ->
        raise "Failed to fetch testing clusters"
    end
  end

  def get_or_create_testing_assessment(client, version, params) do
    version_id = version["id"]

    Req.post!(client,
      url: "/publish/testing/versions/#{version_id}/assessments",
      json: %{assessment: params}
    )
  end

  def authenticate do
    auth_token = System.get_env("POLAR_AUTH_TOKEN")

    body = %{
      user: %{
        password: auth_token
      }
    }

    client = client()

    client
    |> Req.update(url: "/publish/sessions", json: body)
    |> Req.post()
    |> case do
      {:ok, %{body: %{"data" => %{"token" => session_token}}}} ->
        Logger.info("[Polar] Authenticated")

        Req.update(client, headers: [{"authorization", session_token}])

      _ ->
        raise "Failed to authenticate with Polar"
    end
  end

  def client do
    endpoint = System.get_env("POLAR_ENDPOINT", "https://images.opsmaru.com")

    Req.new(base_url: endpoint, finch: Icepak.Finch)
  end
end
