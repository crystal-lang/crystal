class Log
  # Setups *builder* based on `CRYSTAL_LOG_LEVEL` and `CRYSTAL_LOG_SOURCES`
  # environment variables.
  def self.setup_from_env(*, builder : Log::Builder = Log.builder,
                          default_level : Log::Severity = Log::Severity::Info,
                          default_sources = "*",
                          backend = Log::IOBackend.new)
    builder.clear

    level = ENV["CRYSTAL_LOG_LEVEL"]?.try { |v| Log::Severity.parse(v) } || default_level
    sources = ENV["CRYSTAL_LOG_SOURCES"]? || default_sources

    sources.split(',', remove_empty: false) do |source|
      source = source.strip

      builder.bind(source, level, backend)
    end
  end
end
