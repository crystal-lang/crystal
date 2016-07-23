# Implementation of the `crystal tool playground` command
#
# This is just the command-line part. The playground is
# implemented in `crystal/tools/playground/`

class Crystal::Command
  private def playground
    server = Playground::Server.new

    OptionParser.parse(options) do |opts|
      opts.banner = "Usage: crystal play [options] [file]\n\nOptions:"

      opts.on("-p PORT", "--port PORT", "Runs the playground on the specified port") do |port|
        server.port = port.to_i
      end

      opts.on("-b HOST", "--binding HOST", "Binds the playground to the specified IP") do |host|
        server.host = host
      end

      opts.on("-v", "--verbose", "Display detailed information of executed code") do
        server.logger.level = Logger::Severity::DEBUG
      end

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      opts.unknown_args do |before, after|
        if before.size > 0
          server.source = gather_sources([before.first]).first
        end
      end
    end

    server.start
  end
end
