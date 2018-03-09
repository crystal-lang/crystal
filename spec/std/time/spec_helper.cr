def with_env(name, value)
  previous = ENV[name]?
  begin
    ENV[name] = value

    # Reset local time zone
    Time::Location.local = Time::Location.load_local
    yield
  ensure
    ENV[name] = previous
  end
end

ZONEINFO_ZIP = File.join(__DIR__, "..", "data", "zoneinfo.zip")

def with_zoneinfo(path = ZONEINFO_ZIP)
  with_env("ZONEINFO", path) do
    Time::Location.__clear_location_cache

    yield
  end
end
