module Crystal
  module Config
    PATH = {{ env("CRYSTAL_CONFIG_PATH") || "" }}
    VERSION = {{ env("CRYSTAL_CONFIG_VERSION") || `(git describe --tags --long 2>/dev/null)`.stringify.chomp }}
  end
end
