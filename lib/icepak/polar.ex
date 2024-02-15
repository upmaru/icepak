defmodule Icepak.Polar do
  require Logger

  def get_product(key) do
    key = Base.url_encode64(key)

    authenticate()
    |> Req.get!(url: "/publish/products/#{key}")
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
