defmodule Icepak.ChecksTest do
  use ExUnit.Case

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
    test "can run checks", %{
      os: os,
      checks: checks,
      release: release,
      arch: arch,
      variant: variant,
      serial: serial,
      path: path
    } do
      Icepak.PolarMock
      |> expect(:authenticate, fn -> %Req.Request{} end)

      assert result =
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
