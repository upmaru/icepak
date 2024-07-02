import Config

config :icepak, :env, :test
config :icepak, :lexdee, Icepak.LexdeeMock
config :icepak, :polar, Icepak.PolarMock
config :lexdee, :environment, :test
