class Log
  # Setups *builder* based on `LOG_LEVEL` and `LOG_SOURCES`
  # environment variables.
  def self.setup_from_env(*, builder : Log::Builder = Log.builder,
                          default_level : Log::Severity = Log::Severity::Info,
                          default_sources = "*",
                          log_level_env = "LOG_LEVEL",
                          log_sources_env = "LOG_SOURCES",
                          backend = Log::IOBackend.new)
    builder.clear

    level = ENV[log_level_env]?.try { |v| Log::Severity.parse(v) } || default_level
    sources = ENV[log_sources_env]? || default_sources

    sources.split(',', remove_empty: false) do |source|
      source = source.strip

      builder.bind(source, level, backend)
    end
  end
end
