require "http/server"
require "tempfile"
require "logger"
require "ecr/macros"

module Crystal::Playground
  class Session
    @ws : HTTP::WebSocket
    @process : Process?
    @running_process_filename : String
    @logger : Logger
    getter tag : Int32

    def initialize(@ws, @session_key, @port, @logger)
      @running_process_filename = ""
      @tag = 0
    end

    def run(source, tag)
      @logger.info "Request to run code (session=#{@session_key}, tag=#{tag}).\n#{source}"

      @tag = tag
      begin
        ast = Parser.new(source).parse
      rescue ex : Crystal::Exception
        send_exception ex, tag
        return
      end

      instrumented = ast.transform(Playground::AgentInstrumentorTransformer.new).to_s
      @logger.info "Code instrumentation (session=#{@session_key}, tag=#{tag}).\n#{instrumented}"

      prelude = %(
        require "compiler/crystal/tools/playground/agent"
        $p = Crystal::Playground::Agent.new("ws://localhost:#{@port}/agent/#{@session_key}/#{tag}", #{tag})
        )

      sources = [
        Compiler::Source.new("playground_prelude", prelude),
        Compiler::Source.new("play", instrumented),
      ]
      output_filename = tempfile "play-#{@session_key}-#{tag}"
      compiler = Compiler.new
      compiler.color = false
      begin
        @logger.info "Instrumented code compilation started (session=#{@session_key}, tag=#{tag})."
        result = compiler.compile sources, output_filename
      rescue ex : Crystal::Exception
        @logger.info "Instrumented code compilation failed (session=#{@session_key}, tag=#{tag})."

        # due to instrumentation, we compile the original program
        begin
          @logger.info "Original code compilation started (session=#{@session_key}, tag=#{tag})."
          compiler.compile Compiler::Source.new("play", source), output_filename
        rescue ex : Crystal::Exception
          @logger.info "Original code compilation failed (session=#{@session_key}, tag=#{tag})."
          send_exception ex, tag
          return # if we don't exit here we've found a bug
        end

        @logger.error "Instrumention bug found (session=#{@session_key}, tag=#{tag})."
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
      begin
        @ws.send(message)
      rescue ex : IO::Error
        @logger.warn "Unable to send message (session=#{@session_key})."
      end
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
        @logger.info "Code execution killed (session=#{@session_key}, filename=#{@running_process_filename})."
        @process = nil
        File.delete @running_process_filename
        process.kill rescue nil
      end
    end

    private def execute(tag, output_filename)
      stop_process

      @logger.info "Code execution started (session=#{@session_key}, tag=#{tag}, filename=#{output_filename})."
      @process = process = Process.new(output_filename, args: [] of String, input: nil, output: nil, error: nil)
      @running_process_filename = output_filename

      spawn do
        status = process.wait
        @logger.info "Code execution ended (session=#{@session_key}, tag=#{tag}, filename=#{output_filename})."
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

  class PageHandler < HTTP::Handler
    class Page
      def initialize(@filename)
      end

      def content
        File.read(@filename)
      end

      ECR.def_to_s "#{__DIR__}/views/layout.html.ecr"
    end

    def initialize(@path, filename)
      @page = Page.new(filename)
    end

    def call(context)
      case {context.request.method, context.request.resource}
      when {"GET", @path}
        context.response.headers["Content-Type"] = "text/html"
        context.response << @page.to_s
      else
        call_next(context)
      end
    end
  end

  class PathWebSocketHandler < HTTP::WebSocketHandler
    @path : String

    def initialize(@path, &proc : HTTP::WebSocket, HTTP::Server::Context ->)
      super(&proc)
    end

    def call(context)
      if context.request.path.try &.starts_with?(@path)
        super
      else
        call_next(context)
      end
    end
  end

  class EnvironmentHandler < HTTP::Handler
    def initialize(@server)
    end

    def call(context)
      case {context.request.method, context.request.resource}
      when {"GET", "/environment.js"}
        context.response.headers["Content-Type"] = "application/javascript"
        context.response.puts %(Environment = {})

        context.response.puts %(Environment.version = #{("Crystal " + Crystal.version_string).inspect})

        defaultSource = <<-CR
          def find_string(text, word)
            (0..text.size-word.size).each do |i|
              { i, text[i..i+word.size-1] }
              if text[i..i+word.size-1] == word
                return i
              end
            end

            nil
          end

          find_string "Crystal is awesome!", "awesome"
          find_string "Crystal is awesome!", "not sure"
          CR
        context.response.puts "Environment.defaultSource = #{defaultSource.inspect}"

        if source = @server.source
          context.response.puts "Environment.source = #{source.code.inspect};"
        else
          context.response.puts "Environment.source = null;"
        end
      else
        call_next(context)
      end
    end
  end

  class Server
    $sockets = [] of HTTP::WebSocket
    @sessions = {} of Int32 => Session
    @sessions_key = 0

    property host
    property port
    property logger
    property source : Compiler::Source?

    def initialize
      @host = "localhost"
      @port = 8080
      @verbose = false
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::Severity::WARN
    end

    def start
      playground_dir = File.dirname(CrystalPath.new.find("compiler/crystal/tools/playground/server.cr").not_nil![0])
      views_dir = File.join(playground_dir, "views")
      public_dir = File.join(playground_dir, "public")

      agent_ws = PathWebSocketHandler.new "/agent" do |ws, context|
        match_data = context.request.path.not_nil!.match(/\/(\d+)\/(\d+)$/).not_nil!
        session_key = match_data[1]?.try(&.to_i)
        tag = match_data[2]?.try(&.to_i)
        @logger.info "#{context.request.path} WebSocket connected (session=#{session_key}, tag=#{tag})"

        session = @sessions[session_key]

        ws.on_message do |message|
          # ignore if the session is already about another execution.
          if tag == session.tag
            # forward every message to the client.
            session.send(message)
          end
        end
      end

      client_ws = PathWebSocketHandler.new "/client" do |ws|
        @sessions_key += 1
        @sessions[@sessions_key] = session = Session.new(ws, @sessions_key, @port, @logger)
        @logger.info "/client WebSocket connected as session=#{@sessions_key}"

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
        PageHandler.new("/", File.join(views_dir, "_index.html")),
        PageHandler.new("/about", File.join(views_dir, "_about.html")),
        PageHandler.new("/settings", File.join(views_dir, "_settings.html")),
        EnvironmentHandler.new(self),
        HTTP::StaticFileHandler.new(public_dir),
      ]

      puts "Listening on http://#{@host}:#{@port}"
      server.listen
    end
  end
end
