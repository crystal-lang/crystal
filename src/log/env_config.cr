class Log
  # Setups *builder* based on `CRYSTAL_LOG_LEVEL` and `CRYSTAL_LOG_SOURCES`
  # environment variables.
  def self.setup_from_env(*, builder : Log::Builder = Log.builder,
                          level = ENV.fetch("CRYSTAL_LOG_LEVEL", "INFO"),
                          sources = ENV.fetch("CRYSTAL_LOG_SOURCES", ""),
                          backend = Log::IOBackend.new)
    builder.clear

    level = Log::Severity.parse(level)
    sources.split(',', remove_empty: false) do |source|
      source = source.strip

      builder.bind(source, level, backend)
    end
  end
end
