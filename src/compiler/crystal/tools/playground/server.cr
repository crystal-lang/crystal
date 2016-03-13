require "http/server"
require "tempfile"

module Crystal::Playground
  class Session
    @ws : HTTP::WebSocket
    @process : Process?
    @running_process_filename : String
    @output_w : MemoryIO
    getter tag : Int32

    def initialize(@ws, @session_key, @port)
      @running_process_filename = ""
      @output_w = MemoryIO.new
      @tag = 0
    end

    def run(source, tag)
      @tag = tag
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

        at_exit do |status|
          $p.exit(status)
        end
        )

      sources = [
        Compiler::Source.new("playground_prelude", prelude),
        Compiler::Source.new("play", instrumented),
      ]
      output_filename = tempfile "play-#{@session_key}-#{tag}"
      compiler = Compiler.new
      begin
        result = compiler.compile sources, output_filename
      rescue ex : Crystal::Exception
        # due to instrumentation, we compile the original program
        begin
          compiler.compile Compiler::Source.new("play", source), output_filename
        rescue ex : Crystal::Exception
          send_exception ex, tag
          return # if we don't exit here we've found a bug
        end

        send_with_json_builder do |json, io|
          json.field "type", "bug"
          json.field "tag", tag
          json.field "exception" do
            ex.to_json(io)
          end
        end

        return
      end

      execute output_filename

      data = {"type": "run", "tag": tag, "filename": output_filename}
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

    def stream_output
      content = @output_w.to_s

      return if content.empty?

      send_with_json_builder do |json|
        json.field "type", "output"
        json.field "tag", @tag
        json.field "content", content
      end
    end

    private def tempfile(basename)
      Crystal.tempfile(basename)
    end

    private def stop_process
      if process = @process
        @process = nil
        File.delete @running_process_filename
        process.kill rescue nil
        @output_w = MemoryIO.new
      end
    end

    private def execute(output_filename)
      stop_process

      @process = Process.new(output_filename, args: [] of String, input: true, output: @output_w, error: @output_w)
      @running_process_filename = output_filename

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
    $sockets = [] of HTTP::WebSocket
    @sessions = {} of Int32 => Session
    @sessionsKey = 0

    def initialize(@port : Int32)
    end

    def start
      public_dir = File.join(File.dirname(CrystalPath.new.find("compiler/crystal/tools/playground/server.cr").not_nil![0]), "public")

      agent_ws = PathWebSocketHandler.new "/agent" do |ws|
        ws.on_message do |message|
          # forward every message to the client.
          # removing the session key
          json = JSON.parse(message)
          sessionKey = json["session"].as_i
          session = @sessions[sessionKey]
          # ignore if the session is already about another execution
          if json["tag"].as_i == session.tag
            json.as_h.delete "session"
            session.send(json.to_json)

            # temporal solution for streamming output
            case json["type"].as_s
            when "value", "exit"
              session.stream_output
            end
          end
        end
      end

      client_ws = PathWebSocketHandler.new "/client" do |ws|
        @sessionsKey += 1
        @sessions[@sessionsKey] = session = Session.new(ws, @sessionsKey, @port)

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

      server = HTTP::Server.new "localhost", @port, [
        client_ws,
        agent_ws,
        IndexHandler.new(File.join(public_dir, "index.html")),
        HTTP::StaticFileHandler.new(public_dir),
      ]

      puts "Listening on http://0.0.0.0:#{@port}"
      server.listen
    end
  end
end
