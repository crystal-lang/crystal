class Log
  # Setups logging bindings discarding all previous configurations.
  def self.setup(*, builder : Log::Builder = Log.builder)
    builder.clear
    yield builder.as(Configuration)
  end

  # Setups logging for all sources using the specified *level*, *backend*.
  def self.setup(level : Log::Severity = Log::Severity::Info,
                 backend : Log::Backend = IOBackend.new,
                 *, builder : Log::Builder = Log.builder)
    Log.setup("*", level, backend, builder: builder)
  end

  # Setups logging for *sources* using the specified *level*, *backend*.
  def self.setup(sources : String = "*",
                 level : Log::Severity = Log::Severity::Info,
                 backend : Log::Backend = IOBackend.new,
                 *, builder : Log::Builder = Log.builder)
    Log.setup(builder: builder) do |c|
      sources.split(',', remove_empty: false) do |source|
        source = source.strip

        c.bind(source, level, backend)
      end
    end
  end

  # Setups logging based on `LOG_LEVEL` and `LOG_SOURCES`
  # environment variables.
  def self.setup_from_env(*, builder : Log::Builder = Log.builder,
                          default_level : Log::Severity = Log::Severity::Info,
                          default_sources = "*",
                          log_level_env = "LOG_LEVEL",
                          log_sources_env = "LOG_SOURCES",
                          backend = Log::IOBackend.new)
    level = ENV[log_level_env]?.try { |v| Log::Severity.parse(v) } || default_level
    sources = ENV[log_sources_env]? || default_sources

    Log.setup(sources, level, backend, builder: builder)
  end
end
