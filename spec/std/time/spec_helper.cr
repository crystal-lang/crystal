require "../spec_helper"

class Time::Location
  def __cached_zone=(zone)
    @cached_zone = zone
  end

  def self.__clear_location_cache
    @@location_cache.clear
  end
end

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

ZONEINFO_ZIP = datapath("zoneinfo.zip")

def with_zoneinfo(path = ZONEINFO_ZIP)
  with_env("ZONEINFO", path) do
    Time::Location.__clear_location_cache

    yield
  end
end
