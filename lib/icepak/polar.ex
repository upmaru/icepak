defmodule Icepak.Polar do
  def get_storage do
  end

  def client do
    endpoint = System.get_env("POLAR_ENDPOINT", "https://images.opsmaru.com")

    middleware = [
      {Tesla.Middleware.BaseUrl, endpoint},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Logger, debug: false, log_level: &custom_log_level/1}
    ]

    Tesla.client(middleware)
  end

  defp custom_log_level(env) do
    case env.status do
      404 -> :info
      _ -> :default
    end
  end
end
