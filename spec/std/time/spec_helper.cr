def with_env(name, value)
  previous = ENV[name]?
  begin
    ENV[name] = value
    yield
  ensure
    ENV[name] = previous
  end
end

ZONEINFO_ZIP = File.join(__DIR__, "..", "data", "zoneinfo.zip")

def with_zoneinfo(path = ZONEINFO_ZIP)
  with_env("ZONEINFO", path) do
    yield
  end
end
