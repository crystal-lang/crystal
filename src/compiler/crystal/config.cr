module Crystal
  module Config
    PATH = {{ env("CRYSTAL_CONFIG_PATH") || "" }}

    VERSION =
      ifdef linux || darwin
        {{ env("CRYSTAL_CONFIG_VERSION") || `(git describe --tags --long 2>/dev/null)`.stringify.chomp }}
      else
        {{ env("CRYSTAL_CONFIG_VERSION") || "0.6.1-win32".stringify.chomp }}
      end
  end
end
