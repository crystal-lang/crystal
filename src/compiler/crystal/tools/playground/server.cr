require "http/server"
require "tempfile"

module Crystal::Playground
  class Session
    @ws : HTTP::WebSocket

    def initialize(@ws, @session_key, @port)
    end

    def run(source)
      begin
        ast = Parser.new(source).parse
      rescue ex : SyntaxException
        send_with_json_builder do |json, io|
          json.field "type", "parser_error"
          json.field "exception" do
            ex.to_json(io)
          end
        end

        return
      end

      instrumented = Playground::AgentInstrumentorVisitor.new.process(ast).to_s

      prelude = %(
        require "compiler/crystal/tools/playground/agent"
        $p = Crystal::Playground::Agent.new("ws://0.0.0.0:#{@port}", #{@session_key})
        )

      sources = [
        Compiler::Source.new("playground_prelude", prelude),
        Compiler::Source.new("play", instrumented),
      ]
      output_filename = tempfile "play-#{@session_key}"
      compiler = Compiler.new
      result = compiler.compile sources, output_filename
      output = execute output_filename, [] of String

      data = {"type" => "run", "filename" => output_filename, "output" => output[1]}
      send(data.to_json)
    end

    def send(message)
      @ws.send(message)
    end

    def send_with_json_builder
      send(String.build do |io|
        io.json_object do |json|
          yield json, io
        end
      end)
    end

    private def tempfile(basename)
      Crystal.tempfile(basename)
    end

    private def execute(output_filename, run_args)
      begin
        output = MemoryIO.new
        Process.run(output_filename, args: run_args, input: true, output: output, error: output) do |process|
          # Signal::INT.trap do
          #   process.kill
          #   # exit
          # end
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
    @sessions = {} of Int32 => Session
    @sessionsKey = 0

    def start
      public_dir = File.join(File.dirname(CrystalPath.new.find("compiler/crystal/tools/playground/server.cr").not_nil![0]), "public")

      play_ws = HTTP::WebSocketHandler.new do |ws|
        @sessionsKey += 1
        @sessions[@sessionsKey] = session = Session.new(ws, @sessionsKey, PORT)

        ws.on_message do |message|
          pp message
          json = JSON.parse(message)
          case json["type"].as_s
          when "run"
            source = json["source"].as_s
            session.run source
          when "agent_send"
            value = json["value"].as_s
            line = json["line"].as_i
            sessionKey = json["session"].as_i
            data = {"type" => "value", "value" => value, "line" => line}
            @sessions[sessionKey].send(data.to_json)
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
  end
end
