defmodule Icepak.Polar do
  require Logger

  def get_product(client, key) do
    key = Base.url_encode64(key)

    Req.get!(client, url: "/publish/products/#{key}")
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
        Logger.info("Authenticated with Polar")

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
