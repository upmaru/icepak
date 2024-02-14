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

  def main(args \\ []) do
    command = List.first(args)
    call = Map.get(@commands, command)

    if call do
      switches = Map.get(@switches, command, switches: [])

      {options, _, _} = OptionParser.parse(args, switches)

      apply(Pakman, call, [options])
    else
      raise "Unknown command: #{inspect(command)}"
    end
  end
end
