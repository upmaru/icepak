defmodule Icepak.TestingTest do
  use ExUnit.Case, async: true

  alias Icepak.Testing

  test "render configuration for container" do
    params =
      Testing.params(%{
        type: "combined_squashfs_sha256",
        arch: "amd64",
        name: "some-name",
        fingerprint: "some-fingerprint",
        requirements: %{
          "secureboot" => "false"
        }
      })

    assert %{
             "ephemeral" => _,
             "type" => "container",
             "architecture" => "amd64",
             "profiles" => ["default"],
             "source" => _source,
             "name" => _name
           } = params
  end

  test "render configuration for vm" do
    params =
      Testing.params(%{
        type: "combined_disk-kvm-img_sha256",
        arch: "amd64",
        name: "some-name",
        fingerprint: "some-fingerprint",
        requirements: %{
          "secureboot" => "false"
        }
      })

    assert %{
             "ephemeral" => _,
             "type" => "virtual-machine",
             "architecture" => "amd64",
             "profiles" => ["default"],
             "config" => config,
             "source" => _source,
             "name" => _name
           } = params

    assert %{"security.secureboot" => "false"} = config
  end
end
