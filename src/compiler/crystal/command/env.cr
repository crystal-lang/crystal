# Implementation of the `crystal env` command

class Crystal::Command
  private def env
    var_names = [] of String

    OptionParser.parse(@options) do |opts|
      opts.banner = env_usage

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      opts.unknown_args do |before, after|
        var_names = before
      end
    end

    vars = {
      "CRYSTAL_CACHE_DIR"     => CacheDir.instance.dir,
      "CRYSTAL_PATH"          => CrystalPath.default_path,
      "CRYSTAL_VERSION"       => Config.version || "",
      "CRYSTAL_LIBRARY_PATH"  => CrystalLibraryPath.default_path,
      "CRYSTAL_LIBRARY_RPATH" => CrystalLibraryPath.default_rpath,
      "CRYSTAL_OPTS"          => ENV.fetch("CRYSTAL_OPTS", ""),
    }

    if var_names.empty?
      vars.each do |key, value|
        puts "#{key}=#{Process.quote(value)}"
      end
    else
      var_names.each do |key|
        puts vars[key]?
      end
    end
  end

  private def env_usage
    <<-USAGE
    Usage: crystal env [var ...]

    Prints Crystal environment information.

    By default it prints information as a shell script.
    If one or more variable names is given as arguments,
    it prints the value of each named variable on its own line.

    Options:
    USAGE
  end
end
