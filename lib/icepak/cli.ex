defmodule Icepak.CLI do
  @commands %{
    "push" => :push
    "validate" => :validate
  }

  @switches %{
    validate: [
      switches: [
        path: :string,
        serial: :string,
        os: :string,
        arch: :string,
        release: :string,
        variant: :string,
        checks: :string
      ]
    ],
    push: [
      switches: [
        path: :string,
        serial: :string,
        os: :string,
        arch: :string,
        release: :string,
        variant: :string
      ]
    ]
  }

  require Logger

  def main(args \\ []) do
    command = List.first(args)
    call = Map.get(@commands, command)

    if call do
      switches = Map.get(@switches, command, switches: [])

      {options, _, _} = OptionParser.parse(args, switches)

      apply(Icepak, call, [options])
    else
      IO.puts("""
      Unknown command, please use one of the following:

      - push - will push the built image
      - validate - will validate the image
      """)
    end
  end
end
