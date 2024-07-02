defmodule Icepak.ChecksTest do
  use ExUnit.Case, async: true

  alias Icepak.Polar.Cluster
  alias Icepak.Polar.Check

  import Mox

  setup :verify_on_exit!

  setup do
    os = "alpine"
    release = "3.20"
    arch = "amd64"
    variant = "default"
    serial = "20240527-40"
    checks = "ipv4"

    path = "test/support/fixtures/amd64"

    {:ok,
     os: os,
     checks: checks,
     release: release,
     arch: arch,
     variant: variant,
     serial: serial,
     path: path}
  end

  describe "perform" do
    test "can run checks and activate version", %{
      os: os,
      checks: checks,
      release: release,
      arch: arch,
      variant: variant,
      serial: serial,
      path: path
    } do
      Icepak.PolarMock
      |> expect(:authenticate, fn -> Req.new(base_url: "http://localhost:4000") end)

      Icepak.PolarMock
      |> expect(:get_product, fn _client, _product_key ->
        %{
          status: 200,
          body: %{
            "data" => %{
              "id" => 1,
              "key" => "some-key",
              "requirements" => %{"secureboot" => "false"}
            }
          }
        }
      end)

      Icepak.PolarMock
      |> expect(:get_version, fn _client, _product, _serial ->
        %{status: 200, body: %{"data" => %{"id" => 1, "serial" => "blah"}}}
      end)

      Icepak.PolarMock
      |> expect(:transition_version, fn _client, _version, event ->
        assert event["name"] == "test"

        %{status: 201, body: %{"data" => %{"id" => 1, "name" => "test"}}}
      end)

      Icepak.PolarMock
      |> expect(:get_testing_clusters, fn _client ->
        [
          %Cluster{
            id: 1,
            type: "lxd",
            arch: "amd64",
            current_state: "healthy",
            endpoint: "https://localhost:8443",
            private_key: "some-key",
            certificate: "some-cert"
          }
        ]
      end)

      Icepak.PolarMock
      |> expect(:get_testing_checks, fn _client ->
        [
          %Check{id: 1, name: "ipv4"}
        ]
      end)

      Icepak.PolarMock
      |> expect(:get_or_create_testing_assessment, fn _client, _version, _params ->
        %Req.Response{status: 200, body: %{"data" => %{"id" => 1, "current_state" => "created"}}}
      end)

      Icepak.LexdeeMock
      |> expect(:create_project, fn _client, _params ->
        {:ok, %{body: %{"id" => "icepak-test"}}}
      end)

      Icepak.LexdeeMock
      |> expect(:create_instance, fn _client, _params, _options ->
        {:ok, %{body: %{"id" => "some-uuid"}}}
      end)

      Icepak.LexdeeMock
      |> expect(:wait_for_operation, fn _client, _params, _options ->
        {:ok, %{body: %{"id" => "some-uuid"}}}
      end)

      Icepak.LexdeeMock
      |> expect(:start_instance, fn _client, _params, _options ->
        {:ok, %{body: %{"id" => "some-uuid"}}}
      end)

      Icepak.LexdeeMock
      |> expect(:wait_for_operation, fn _client, _params, _options ->
        {:ok, %{body: %{"id" => "some-uuid"}}}
      end)

      Icepak.LexdeeMock
      |> expect(:get_state, fn _client, _params, _options ->
        body = %{
          "network" => %{
            "eth0" => %{
              "addresses" => [
                %{
                  "address" => "127.0.0.1",
                  "family" => "inet"
                }
              ]
            }
          }
        }

        {:ok, %{body: body}}
      end)

      Icepak.PolarMock
      |> expect(:transition_testing_assessment, 2, fn _client, _assessment, params ->
        %Req.Response{status: 201, body: %{"data" => %{"id" => 1, "name" => params.name}}}
      end)

      Icepak.LexdeeMock
      |> expect(:stop_instance, fn _client, _params, _options ->
        {:ok, %{body: %{"id" => "some-uuid"}}}
      end)

      Icepak.LexdeeMock
      |> expect(:wait_for_operation, fn _client, _params, _options ->
        {:ok, %{body: %{"id" => "some-uuid"}}}
      end)

      Icepak.PolarMock
      |> expect(:transition_version, fn _client, _version, event ->
        assert event["name"] == "activate"

        %Req.Response{status: 201, body: %{"data" => %{"id" => 1, "name" => "activate"}}}
      end)

      assert %{status: 201, body: %{"data" => event}} =
               Icepak.Checks.perform(
                 os: os,
                 checks: checks,
                 release: release,
                 arch: arch,
                 variant: variant,
                 serial: serial,
                 path: path
               )

      assert event["name"] == "activate"
    end

    test "skip passed assessment", %{
      os: os,
      checks: checks,
      release: release,
      arch: arch,
      variant: variant,
      serial: serial,
      path: path
    } do
      Icepak.PolarMock
      |> expect(:authenticate, fn -> Req.new(base_url: "http://localhost:4000") end)

      Icepak.PolarMock
      |> expect(:get_product, fn _client, _product_key ->
        %{
          status: 200,
          body: %{
            "data" => %{
              "id" => 1,
              "key" => "some-key",
              "requirements" => %{"secureboot" => "false"}
            }
          }
        }
      end)

      Icepak.PolarMock
      |> expect(:get_version, fn _client, _product, _serial ->
        %{status: 200, body: %{"data" => %{"id" => 1, "serial" => "blah"}}}
      end)

      Icepak.PolarMock
      |> expect(:transition_version, fn _client, _version, event ->
        assert event["name"] == "test"

        %{status: 201, body: %{"data" => %{"id" => 1, "name" => "test"}}}
      end)

      Icepak.PolarMock
      |> expect(:get_testing_clusters, fn _client ->
        [
          %Cluster{
            id: 1,
            type: "lxd",
            arch: "amd64",
            current_state: "healthy",
            endpoint: "https://localhost:8443",
            private_key: "some-key",
            certificate: "some-cert"
          }
        ]
      end)

      Icepak.PolarMock
      |> expect(:get_testing_checks, fn _client ->
        [
          %Check{id: 1, name: "ipv4"}
        ]
      end)

      Icepak.PolarMock
      |> expect(:get_or_create_testing_assessment, fn _client, _version, _params ->
        %Req.Response{status: 200, body: %{"data" => %{"id" => 1, "current_state" => "passed"}}}
      end)

      Icepak.PolarMock
      |> expect(:transition_version, fn _client, _version, event ->
        assert event["name"] == "activate"

        %Req.Response{status: 201, body: %{"data" => %{"id" => 1, "name" => "activate"}}}
      end)

      assert %{status: 201, body: %{"data" => _event}} =
               Icepak.Checks.perform(
                 os: os,
                 checks: checks,
                 release: release,
                 arch: arch,
                 variant: variant,
                 serial: serial,
                 path: path
               )
    end
  end
end
