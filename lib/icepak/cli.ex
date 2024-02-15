defmodule Icepak.CLI do
  @commands %{
    "push" => :push
  }

  @switches %{
    push: [
      switches: [
        path: :string,
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
      """)
    end
  end
end
