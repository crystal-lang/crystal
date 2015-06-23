module Crystal
  module Config
    PATH = {{ env("CRYSTAL_CONFIG_PATH") || "" }}
    VERSION = {{ env("CRYSTAL_CONFIG_VERSION") || `(git describe --tags --long 2>/dev/null)`.stringify.chomp }}
    CACHE_DIR = ENV["CRYSTAL_CACHE_DIR"]? || ".crystal"

    def self.cache_dir
      @@cache_dir ||= File.expand_path(CACHE_DIR)
    end
  end
end
