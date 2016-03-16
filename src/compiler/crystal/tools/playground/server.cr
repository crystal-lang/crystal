require "http/server"
require "tempfile"

module Crystal::Playground
  class Session
    @ws : HTTP::WebSocket
    @process : Process?
    @running_process_filename : String
    getter tag : Int32

    def initialize(@ws, @session_key, @port)
      @running_process_filename = ""
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

      instrumented = ast.transform(Playground::AgentInstrumentorTransformer.new).to_s

      prelude = %(
        require "compiler/crystal/tools/playground/agent"
        $p = Crystal::Playground::Agent.new("ws://localhost:#{@port}/agent", #{@session_key}, #{tag})
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
            append_exception io, ex
          end
        end

        return
      end

      execute tag, output_filename

      send_with_json_builder do |json, io|
        json.field "type", "run"
        json.field "tag", tag
        json.field "filename", output_filename
      end
    end

    def stop
      stop_process
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
          append_exception io, ex
        end
      end
    end

    def append_exception(io, ex)
      io.json_object do |json|
        json.field "message", ex.to_s
        json.field "payload", ex
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
      end
    end

    private def execute(tag, output_filename)
      stop_process

      @process = process = Process.new(output_filename, args: [] of String, input: nil, output: nil, error: nil)
      @running_process_filename = output_filename

      spawn do
        status = process.wait
        exit_status = status.normal_exit? ? status.exit_code : status.exit_signal.value

        send_with_json_builder do |json, io|
          json.field "type", "exit"
          json.field "tag", tag
          json.field "status", exit_status
        end
      end

      bind_io_as_output tag, process.output
      bind_io_as_output tag, process.error
    end

    private def bind_io_as_output(tag, io)
      spawn do
        loop do
          begin
            output = String.new(4096) do |buffer|
              length = io.read_utf8(Slice.new(buffer, 4096))
              {length, 0}
            end
            unless output.empty?
              send_with_json_builder do |json|
                json.field "type", "output"
                json.field "tag", tag
                json.field "content", output
              end
            else
              break
            end
          rescue
            break
          end
        end
      end
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

    def initialize(@host : String, @port : Int32)
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
          when "stop"
            session.stop
          end
        end
      end

      server = HTTP::Server.new @host, @port, [
        client_ws,
        agent_ws,
        IndexHandler.new(File.join(public_dir, "index.html")),
        HTTP::StaticFileHandler.new(public_dir),
      ]

      puts "Listening on http://#{@host}:#{@port}"
      server.listen
    end
  end
end
