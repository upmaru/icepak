defmodule Icepak.Polar.Behaviour do
  @callback authenticate() :: %Req.Request{}
end
