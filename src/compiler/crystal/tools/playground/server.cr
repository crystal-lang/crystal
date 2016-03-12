require "http/server"
require "tempfile"

module Crystal::Playground
  class Session
    @ws : HTTP::WebSocket

    def initialize(@ws, @session_key, @port)
    end

    def run(source, tag)
      begin
        ast = Parser.new(source).parse
      rescue ex : Crystal::Exception
        send_exception ex, tag
        return
      end

      instrumented = Playground::AgentInstrumentorVisitor.new.process(ast).to_s

      prelude = %(
        require "compiler/crystal/tools/playground/agent"
        $p = Crystal::Playground::Agent.new("ws://0.0.0.0:#{@port}/agent", #{@session_key}, #{tag})
        )

      sources = [
        Compiler::Source.new("playground_prelude", prelude),
        Compiler::Source.new("play", instrumented),
      ]
      output_filename = tempfile "play-#{@session_key}"
      compiler = Compiler.new
      begin
        result = compiler.compile sources, output_filename
      rescue ex : Crystal::Exception
        # due to instrumentation, we compile the original program
        begin
          compiler.compile Compiler::Source.new("play", source), output_filename
        rescue ex : Crystal::Exception
          puts ex
          send_exception ex, tag
          return # if we don't exit here we've found a bug
        end

        send({"type": "bug", "tag": tag}.to_json)
        return
      end
      output = execute output_filename, [] of String

      data = {"type": "run", "tag": tag, "filename": output_filename, "output": output[1]}
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

    def send_exception(ex, tag)
      send_with_json_builder do |json, io|
        json.field "type", "exception"
        json.field "tag", tag
        json.field "exception" do
          ex.to_json(io)
        end
      end
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

  class PathWebSocketHandler < HTTP::WebSocketHandler
    @path : String

    def initialize(@path, &proc : HTTP::WebSocket ->)
      super(&proc)
    end

    def call(context)
      if context.request.path == @path
        super
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

      agent_ws = PathWebSocketHandler.new "/agent" do |ws|
        ws.on_message do |message|
          # forward every message to the client.
          # removing the session key
          json = JSON.parse(message)
          sessionKey = json["session"].as_i
          json.as_h.delete "session"
          @sessions[sessionKey].send(json.to_json)
        end
      end

      client_ws = PathWebSocketHandler.new "/client" do |ws|
        @sessionsKey += 1
        @sessions[@sessionsKey] = session = Session.new(ws, @sessionsKey, PORT)

        ws.on_message do |message|
          json = JSON.parse(message)
          case json["type"].as_s
          when "run"
            source = json["source"].as_s
            tag = json["tag"].as_i
            session.run source, tag
          end
        end
      end

      server = HTTP::Server.new "localhost", PORT, [
        client_ws,
        agent_ws,
        IndexHandler.new(File.join(public_dir, "index.html")),
        HTTP::StaticFileHandler.new(public_dir),
      ]

      puts "Listening on http://0.0.0.0:#{PORT}"
      server.listen
    end
  end
end
