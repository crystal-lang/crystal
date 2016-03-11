require "http/server"
require "tempfile"

module Crystal::Playground
  class IndexHandler < HTTP::Handler
    def initialize(@filename)
    end

    def call(context)
      case {context.request.method, context.request.resource}
      when {"GET", "/"}
        context.response.headers["Content-Type"] = "text/html"
        context.response << File.read(@filename)
      else
        call_next(context)
      end
    end
  end

  class Server
    PORT = 8080
    $sockets = [] of HTTP::WebSocket
    $socket_data = [] of Hash(String, Int32 | String)

    def start
      public_dir = File.join(File.dirname(CrystalPath.new.find("compiler/crystal/tools/playground/server.cr").not_nil![0]), "public")

      play_ws = HTTP::WebSocketHandler.new do |ws|
        $sockets << ws

        ws.on_message do |message|
          pp message
          json = JSON.parse(message)
          case json["type"].as_s
          when "run"
            $socket_data.clear
            source = json["source"].as_s

            ast = Parser.new(source).parse
            instrumented = Playground::AgentInstrumentorVisitor.new.process(ast).to_s

            prelude = <<-CR
            require "compiler/crystal/tools/playground/agent"
            $p = Crystal::Playground::Agent.new("ws://0.0.0.0:#{PORT}", 0)
            CR

            sources = [
              Compiler::Source.new("playground_prelude", prelude),
              Compiler::Source.new("play", instrumented),
            ]
            output_filename = tempfile "play"
            compiler = Compiler.new
            result = compiler.compile sources, output_filename
            output = execute output_filename, [] of String

            data = {"type" => "run", "filename" => output_filename, "output" => output[1]}
            ws.send(data.to_json)
          when "agent_send"
            value = json["value"].as_s
            line = json["line"].as_i
            session = json["session"].as_i
            data = {"type" => "value", "value" => value, "line" => line}
            $sockets[session].send(data.to_json)
          end
        end
      end

      server = HTTP::Server.new "localhost", PORT, [
        play_ws,
        IndexHandler.new(File.join(public_dir, "index.html")),
        HTTP::StaticFileHandler.new(public_dir),
      ]

      puts "Listening on http://0.0.0.0:#{PORT}"
      server.listen
    end

    private def tempfile(basename)
      Crystal.tempfile(basename)
    end

    private def execute(output_filename, run_args)
      begin
        output = MemoryIO.new
        Process.run(output_filename, args: run_args, input: true, output: output, error: output) do |process|
          Signal::INT.trap do
            process.kill
            # exit
          end
        end
        status = $?
      ensure
        File.delete output_filename
      end

      output.rewind

      {$?, output.to_s}

      # if status.normal_exit?
      #   exit status.exit_code
      # else
      #   case status.exit_signal
      #   when Signal::KILL
      #     STDERR.puts "Program was killed"
      #   when Signal::SEGV
      #     STDERR.puts "Program exited because of a segmentation fault (11)"
      #   else
      #     STDERR.puts "Program received and didn't handle signal #{status.exit_signal} (#{status.exit_signal.value})"
      #   end

      #   exit 1
      # end
    end
  end
end
