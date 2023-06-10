# Implementation of the `crystal clear_cache` command

class Crystal::Command
  private def clear_cache
    OptionParser.parse(@options) do |opts|
      opts.banner = <<-'BANNER'
        Usage: crystal clear_cache

        Clears the compiler cache

        Options:
        BANNER

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end
    puts "clearing compiler cache at \"#{CacheDir.instance.dir}\""
    FileUtils.rm_rf(CacheDir.instance.dir)
  end
end
