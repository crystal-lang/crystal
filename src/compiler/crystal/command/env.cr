# Implementation of the `crystal env` command

class Crystal::Command
  private def env
    if ARGV.size == 1 && ARGV[0].in?("--help", "-h")
      env_usage
    end

    vars = {
      "CRYSTAL_CACHE_DIR"    => CacheDir.instance.dir,
      "CRYSTAL_PATH"         => CrystalPath.default_path,
      "CRYSTAL_VERSION"      => Config.version || "",
      "CRYSTAL_LIBRARY_PATH" => CrystalLibraryPath.default_path,
      "CRYSTAL_OPTS"         => ENV.fetch("CRYSTAL_OPTS", ""),
    }

    if ARGV.empty?
      vars.each do |key, value|
        puts "#{key}=#{Process.quote(value)}"
      end
    else
      ARGV.each do |key|
        puts vars[key]?
      end
    end
  end

  private def env_usage
    puts <<-USAGE
    Usage: crystal env [var ...]

    Prints Crystal environment information.

    By default it prints information as a shell script.
    If one or more variable names is given as arguments,
    it prints the value of each named variable on its own line.
    USAGE

    exit
  end
end
