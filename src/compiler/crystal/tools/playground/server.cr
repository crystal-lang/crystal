require "http/server"
require "log"
require "ecr/macros"
require "compiler/crystal/tools/formatter"
require "../../../../../lib/markd/src/markd"

module Crystal::Playground
  Log = ::Log.for("crystal.playground")

  class Session
    getter tag : Int32

    def initialize(@ws : HTTP::WebSocket, @session_key : Int32, @port : Int32, @host : String? = "localhost")
      @running_process_filename = ""
      @tag = 0
    end

    def self.instrument_and_prelude(session_key, port, tag, source, host : String? = "localhost")
      # TODO: figure out how syntax warnings should be reported
      ast = Parser.new(source).parse

      instrumented = Playground::AgentInstrumentorTransformer.transform(ast).to_s
      Log.info { "Code instrumentation (session=#{session_key}, tag=#{tag}).\n#{instrumented}" }

      prelude = <<-CRYSTAL
        require "compiler/crystal/tools/playground/agent"

        class Crystal::Playground::Agent
          @@instance = Crystal::Playground::Agent.new("ws://#{host}:#{port}/agent/#{session_key}/#{tag}", #{tag})

          def self.instance
            @@instance
          end
        end

        def _p
          Crystal::Playground::Agent.instance
        end
        CRYSTAL

      [
        Compiler::Source.new("playground_prelude", prelude),
        Compiler::Source.new("play", instrumented),
      ]
    end

    def run(source, tag)
      Log.info { "Request to run code (session=#{@session_key}, tag=#{tag}).\n#{source}" }

      @tag = tag
      begin
        sources = self.class.instrument_and_prelude(@session_key, @port, tag, source, host: @host)
      rescue ex : Crystal::CodeError
        send_exception ex, tag
        return
      end

      output_filename = Crystal.temp_executable "play-#{@session_key}-#{tag}"
      compiler = Compiler.new
      compiler.color = false
      begin
        Log.info { "Instrumented code compilation started (session=#{@session_key}, tag=#{tag})." }
        compiler.compile sources, output_filename
      rescue ex
        Log.info { "Instrumented code compilation failed (session=#{@session_key}, tag=#{tag})." }

        # due to instrumentation, we compile the original program
        begin
          Log.info { "Original code compilation started (session=#{@session_key}, tag=#{tag})." }
          compiler.compile Compiler::Source.new("play", source), output_filename
        rescue ex
          Log.info { "Original code compilation failed (session=#{@session_key}, tag=#{tag})." }
          send_exception ex, tag
          return # if we don't exit here we've found a bug
        end

        Log.error { "Instrumentation bug found (session=#{@session_key}, tag=#{tag})." }
        send_with_json_builder do |json|
          json.field "type", "bug"
          json.field "tag", tag
          json.field "exception" do
            append_exception json, ex
          end
        end

        return
      end

      execute tag, output_filename

      send_with_json_builder do |json|
        json.field "type", "run"
        json.field "tag", tag
        json.field "filename", output_filename
      end
    end

    def format(source, tag)
      Log.info { "Request to format code (session=#{@session_key}, tag=#{tag}).\n#{source}" }

      @tag = tag

      begin
        value = Crystal.format source
      rescue ex : Crystal::CodeError
        send_exception ex, tag
        return
      end

      send_with_json_builder do |json|
        json.field "type", "format"
        json.field "tag", tag
        json.field "value", value
      end
    end

    def stop
      stop_process
    end

    def send(message)
      @ws.send(message)
    rescue ex : IO::Error
      Log.warn { "Unable to send message (session=#{@session_key})." }
    end

    def send_with_json_builder(&)
      send(JSON.build do |json|
        json.object do
          yield json
        end
      end)
    end

    def send_exception(ex, tag)
      send_with_json_builder do |json|
        json.field "type", "exception"
        json.field "tag", tag
        json.field "exception" do
          append_exception json, ex
        end
      end
    end

    def append_exception(json, ex)
      json.object do
        json.field "message", ex.to_s
        if ex.is_a?(Crystal::CodeError)
          json.field "payload" do
            ex.to_json(json)
          end
        end
      end
    end

    private def stop_process
      if process = @process
        Log.info { "Code execution killed (session=#{@session_key}, filename=#{@running_process_filename})." }
        @process = nil
        File.delete? @running_process_filename
        process.terminate rescue nil
      end
    end

    private def execute(tag, output_filename)
      stop_process

      Log.info { "Code execution started (session=#{@session_key}, tag=#{tag}, filename=#{output_filename})." }
      process = @process = Process.new(output_filename, args: [] of String, input: Process::Redirect::Pipe, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
      @running_process_filename = output_filename

      spawn do
        status = process.wait
        Log.info { "Code execution ended (session=#{@session_key}, tag=#{tag}, filename=#{output_filename})." }

        send_with_json_builder do |json|
          json.field "type", "exit"
          json.field "tag", tag
          json.field "status", status.to_s
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

  abstract class PlaygroundPage
    getter styles = [] of String
    getter scripts = [] of String

    def render_with_layout(io, &block)
      ECR.embed "#{__DIR__}/views/layout.html.ecr", io
    end
  end

  class FileContentPage < PlaygroundPage
    def initialize(@filename : String)
    end

    def content
      extname = File.extname(@filename)
      content = if extname == ".cr"
                  crystal_source_to_markdown(@filename)
                else
                  File.read(@filename)
                end

      if extname.in?(".md", ".cr")
        content = Markd.to_html(content)
      end
      content
    rescue e
      e.message || "Error: generating content for #{@filename}"
    end

    def to_s(io : IO) : Nil
      body = content
      # avoid the layout if the file is a full html
      if File.extname(@filename).starts_with?(".htm") && content.starts_with?("<!")
        io << body
      else
        render_with_layout(io) do
          body
        end
      end
    end

    private def crystal_source_to_markdown(filename)
      String.build do |io|
        header = true
        File.each_line(filename, chomp: false) do |line|
          if header && line[0] != '\n' && line[0] != '#'
            header = false
            io << "```playground\n"
          end

          if header
            io << line.sub(/^\#\ /, "")
          else
            io << line
          end
        end

        unless header
          io << "```"
        end
      end
    end
  end

  class WorkbookIndexPage < PlaygroundPage
    record Item, title : String, path : String

    def items
      files.map do |f|
        ext = File.extname(f)
        title = File.basename(f)[0..-ext.size - 1].gsub(/[_-]/, " ").camelcase
        Item.new(title, "/workbook/#{f[0..-ext.size - 1]}")
      end
    end

    def has_items
      !files.empty?
    end

    private def files
      Dir["playground/*.{md,html,cr}"]
    end

    def to_s(io : IO) : Nil
      render_with_layout(io) do
        ECR.embed "#{__DIR__}/views/_workbook.html.ecr", io
        nil
      end
    end
  end

  class PageHandler
    include HTTP::Handler

    @page : PlaygroundPage

    def initialize(@path : String, filename : String)
      @page = FileContentPage.new(filename)
    end

    def initialize(@path : String, @page : PlaygroundPage)
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

  class WorkbookHandler
    include HTTP::Handler

    def call(context)
      case {context.request.method, context.request.path}
      when {"GET", /\/workbook\/playground\/(.*)/}
        files = Dir["playground/#{$1}.{md,html,cr}"]
        if files.size > 0
          context.response.headers["Content-Type"] = "text/html"
          page = FileContentPage.new(files[0])
          load_resources page
          context.response << page
          return
        end
      else
        # Not a special path
      end

      call_next(context)
    end

    def load_resources(page : PlaygroundPage)
      Dir["playground/resources/*.css"].each do |file|
        page.styles << "/workbook/#{file}"
      end
      Dir["playground/resources/*.js"].each do |file|
        page.scripts << "/workbook/#{file}"
      end
    end
  end

  class PathStaticFileHandler < HTTP::StaticFileHandler
    def initialize(@path : String, public_dir : String, fallthrough = true)
      super(public_dir, fallthrough)
    end

    def call(context)
      if context.request.path.try &.starts_with?(@path)
        super
      else
        call_next(context)
      end
    end

    def request_path(path : String) : String
      path[@path.size..-1]
    end
  end

  class PathWebSocketHandler < HTTP::WebSocketHandler
    def initialize(@path : String, &proc : HTTP::WebSocket, HTTP::Server::Context ->)
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

  class EnvironmentHandler
    include HTTP::Handler

    DEFAULT_SOURCE = <<-CRYSTAL
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
      CRYSTAL

    def initialize(@server : Playground::Server)
    end

    def call(context)
      case {context.request.method, context.request.resource}
      when {"GET", "/environment.js"}
        context.response.headers["Content-Type"] = "application/javascript"

        context.response.puts <<-JS
          Environment = {}
          Environment.version = #{Crystal::Config.description.inspect}
          Environment.defaultSource = #{DEFAULT_SOURCE.inspect}
          JS

        if source = @server.source
          context.response.puts "Environment.source = #{source.code.inspect}"
        else
          context.response.puts "Environment.source = null"
        end
      else
        call_next(context)
      end
    end
  end

  class Error < Crystal::Error
  end

  class Server
    @sessions = {} of Int32 => Session
    @sessions_key = 0

    property host : String?
    property port
    property source : Compiler::Source?

    def initialize
      @host = nil
      @port = 8080
      @verbose = false
    end

    def start
      playground_dir = File.dirname(CrystalPath.new.find("compiler/crystal/tools/playground/server.cr").not_nil![0])
      views_dir = File.join(playground_dir, "views")
      public_dir = File.join(playground_dir, "public")

      agent_ws = PathWebSocketHandler.new "/agent" do |ws, context|
        match_data = context.request.path.not_nil!.match(/\/(\d+)\/(\d+)$/).not_nil!
        session_key = match_data[1].to_i
        tag = match_data[2].to_i
        Log.info { "#{context.request.path} WebSocket connected (session=#{session_key}, tag=#{tag})" }

        session = @sessions[session_key]

        ws.on_message do |message|
          # ignore if the session is already about another execution.
          if tag == session.tag
            # forward every message to the client.
            session.send(message)
          end
        end
      end

      client_ws = PathWebSocketHandler.new "/client" do |ws, context|
        origin = context.request.headers["Origin"]
        if !accept_request?(origin)
          Log.warn { "Invalid Request Origin: #{origin}" }
          ws.close :policy_violation, "Invalid Request Origin"
        else
          @sessions_key += 1
          @sessions[@sessions_key] = session = Session.new(ws, @sessions_key, @port, host: @host)
          Log.info { "/client WebSocket connected as session=#{@sessions_key}" }

          ws.on_message do |message|
            json = JSON.parse(message)
            case json["type"].as_s
            when "run"
              source = json["source"].as_s
              tag = json["tag"].as_i
              session.run source, tag
            when "stop"
              session.stop
            when "format"
              source = json["source"].as_s
              tag = json["tag"].as_i
              session.format source, tag
            else
              # TODO: maybe raise because it's an unexpected message?
            end
          end
        end
      end

      handlers = [
        client_ws,
        agent_ws,
        PageHandler.new("/", File.join(views_dir, "_index.html")),
        PageHandler.new("/about", File.join(views_dir, "_about.html")),
        PageHandler.new("/settings", File.join(views_dir, "_settings.html")),
        PageHandler.new("/workbook", WorkbookIndexPage.new),
        PathStaticFileHandler.new("/workbook/playground/resources", "playground/resources", false),
        WorkbookHandler.new,
        EnvironmentHandler.new(self),
        HTTP::StaticFileHandler.new(public_dir),
      ]

      server = HTTP::Server.new handlers

      address = server.bind_tcp @host || Socket::IPAddress::LOOPBACK, @port
      @port = address.port
      @host = address.address

      puts "Listening on http://#{address}"
      if address.unspecified?
        puts "WARNING running playground on #{address.address} is insecure."
      end

      begin
        server.listen
      rescue ex
        raise Playground::Error.new(ex.message)
      end
    rescue e : Socket::BindError
      raise Playground::Error.new(e.message)
    end

    private def accept_request?(origin)
      case @host
      when nil, "localhost", "127.0.0.1"
        origin.in?("http://localhost:#{@port}", "http://127.0.0.1:#{@port}")
      when "0.0.0.0"
        true
      else
        origin == "http://#{@host}:#{@port}"
      end
    end
  end
end
