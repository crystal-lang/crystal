require "option_parser"
require "thread"
require "io"
require "file_utils"
require "socket"
require "net/http"

lib C
  fun mkstemp(result : UInt8*) : Int32
end

module Crystal
  class Compiler
    include Crystal

    getter config
    getter llc
    getter opt
    getter clang
    getter llvm_dis
    getter dump_ll
    getter debug
    getter release
    getter llc_flags
    getter llc_flags_changed
    getter cross_compile
    getter! output_dir

    def initialize
      @dump_ll = false
      @no_build = false
      @print_types = false
      @print_hierarchy = false
      @run = false
      @stats = false
      @debug = false
      @release = false
      @output_filename = nil
      @llc_flags = nil
      @command = nil
      @cross_compile = nil
      @llc_flags_changed = true
      @multithreaded = false
      @prelude = "prelude"
      @n_threads = 8.to_i32
      @browser = false
      @single_module = false

      @config = LLVMConfig.new
      @llc = @config.bin "llc"
      @opt = @config.bin "opt"
      @clang = @config.bin "clang"
      @llvm_dis = @config.bin "llvm-dis"

      Crystal.dump_version

      @options = OptionParser.parse! do |opts|
        opts.banner = "Crystal #{Crystal.version_string}\nUsage: crystal [switches] [--] [programfile] [arguments]"
        opts.on("-v", "--version", "Crystal version") do
          puts Crystal.version_string
          exit
        end
        opts.on("--browser", "Opens an http server to browse the code") do
          @browser = true
        end
        opts.on("--cross-compile flags", "cross-compile") do |cross_compile|
          @cross_compile = cross_compile
        end
        opts.on("-d", "--debug", "Add symbolic debug info") do
          @debug = true
        end
        opts.on("-e 'command'", "One line script. Omit [programfile]") do |command|
          @command = command
        end
        opts.on("--hierarchy", "Prints types hierarchy") do
          @print_hierarchy = true
        end
        opts.on("--ll", "Dump ll to .crystal directory") do
          @dump_ll = true
        end
        opts.on("--llc ", "Additional flags to pass to llc") do |llc_flags|
          @llc_flags = llc_flags
        end
        opts.on("--no-build", "Disable build output") do
          @no_build = true
        end
        opts.on("-o ", "Output filename") do |output_filename|
          @output_filename = output_filename
        end
        opts.on("--prelude ", "Use given file as prelude") do |prelude|
          @prelude = prelude
        end
        opts.on("--release", "Compile in release mode") do
          @release = true
        end
        opts.on("--run", "Execute program") do
          @run = true
        end
        opts.on("-s", "--stats", "Enable statistis output") do
          @stats = true
        end
        opts.on("--single-module", "Generate a single LLVM module") do
          @single_module = true
        end
        opts.on("-t", "--types", "Prints types of global variables") do
          @print_types = true
        end
        opts.on("--threads ", "Maximum number of threads to use") do |n_threads|
          @n_threads = n_threads.to_i32
        end
        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit 1
        end
      end
    end

    def compile
      if command = @command
        source = command
        filename = "-"
        @run = true
      else
        if ARGV.length == 0
          puts @options
          exit 1
        end

        filename = ARGV[0]
        unless File.exists?(filename)
          puts "File #{filename} does not exist"
          exit 1
        end

        filename = File.expand_path(filename) #unless filename == '-'
        source = File.read filename
      end

      output_filename = @output_filename
      unless output_filename
        if @run
          output_filename = "#{ENV["TMPDIR"] || "/tmp"}/.crystal-run.XXXXXX"
          tmp_fd = C.mkstemp output_filename
          raise "Error creating temp file #{output_filename}" if tmp_fd == -1
          C.close tmp_fd
        else
          output_filename = File.basename(filename, File.extname(filename))
        end
      end

      begin
        program = Program.new
        if cross_compile = @cross_compile
          program.flags = cross_compile
        end

        unless File.exists?(@clang)
          if program.has_flag?("darwin")
            puts "Could not find clang. Install clang 3.3: brew tap homebrew/versions; brew install llvm33 --with-clang"
            exit 1
          end

          clang = program.exec "which gcc"
          if clang
            @clang = clang
          else
            puts "Could not find a C compiler. Install clang (3.3) or gcc."
            exit 1
          end
        end

        parser = Parser.new(source)
        parser.filename = filename
        node = parser.parse

        require_node = Require.new(@prelude)
        require_node.location = Location.new(1, 1, filename)

        timing("Normalize") do
          require_node = program.normalize(require_node)
          node = program.normalize(node)
        end

        original_node = node
        node = Expressions.new([require_node, node] of ASTNode)

        node = timing("Type inference") do
          program.infer_type node
        end

        print_types node if @print_types
        print_hierarchy program if @print_hierarchy
        return open_browser(original_node) if @browser

        return if @no_build

        llvm_modules = timing("Codegen (crystal)") do
          options = Program::BuildOptions.new
          options.single_module = @single_module || @release || @cross_compile
          options.debug = @debug
          program.build node, options
        end

        if @cross_compile
          output_dir = "."
        else
          output_dir = ".crystal/#{filename}"
        end

        Dir.mkdir_p(output_dir)
        @output_dir = output_dir

        units = llvm_modules.map do |type_name, llvm_mod|
          CompilationUnit.new(self, type_name, llvm_mod)
        end
        object_names = units.map &.object_name

        if @cross_compile
          compilation_unit = units.first
          compilation_unit_bc_name = "#{output_filename}.bc"
          compilation_unit_s_name = "#{output_filename}.s"
          compilation_unit.write_bitcode compilation_unit_bc_name
          system "#{opt} #{compilation_unit_bc_name} -O3 -o #{compilation_unit_bc_name}" if @release
          puts "llc #{compilation_unit_bc_name} #{llc_flags} -o #{compilation_unit_s_name} && clang #{compilation_unit_s_name} -o #{output_filename} #{lib_flags(program)}"
        else
          multithreaded = LLVM.start_multithreaded

          # First write bitcodes: it breaks if we paralellize it
          unless multithreaded
            timing("Codegen (bitcode)") do
              units.each &.write_bitcode
            end
          end

          mutex = Mutex.new

          llc_flags_filename = "#{output_dir}/llc_flags"
          if File.exists?(llc_flags_filename)
            previous_llc_flags = File.read(llc_flags_filename).strip
            if previous_llc_flags.empty?
              llc_flags_changed = !!@llc_flags
            else
              llc_flags_changed = @llc_flags != previous_llc_flags
            end
          else
            llc_flags_changed = !!@llc_flags
          end

          @llc_flags_changed = llc_flags_changed

          msg = multithreaded ? "Codegen (bitcode+llc+clang)" : "Codegen (llc+clang)"
          timing(msg) do
            threads = Array.new(@n_threads) do
              Thread.new ->do
                while unit = mutex.synchronize { units.shift? }
                  unit.write_bitcode if multithreaded
                  unit.compile
                end
              end
            end
            threads.each &.join
          end

          timing("Codegen (clang)") do
            system "#{@clang} -o #{output_filename} #{object_names.join " "} #{lib_flags(program)}"
          end

          if @llc_flags
            File.open(llc_flags_filename, "w") do |file|
              file.puts @llc_flags
            end
          else
            system "rm -rf #{llc_flags_filename}"
          end

          if @run
            errcode = C.system("#{output_filename} #{ARGV[1 .. -1].join " "}")
            puts "Program terminated abnormally with eror code: #{errcode}" if errcode != 0
            File.delete output_filename
          end
        end
      rescue ex
        puts ex
        exit 1
      end
    end

    def open_browser(node)
      browser = Browser.new(node)
      server, port = create_server
      puts "Browser open at http://0.0.0.0:#{port}"
      ifdef darwin
        system "open http://localhost:#{port}"
      end
      while true
        server.accept do |sock|
          if request = HTTPRequest.from_io(sock)
            html = browser.handle(request.path)
            response = HTTPResponse.new("HTTP/1.1", 200, "OK", {"Content-Type" => "text/html"}, html)
            response.to_io sock
          end
        end
      end
    end

    def create_server(port = 4000)
      {TCPServer.new(port), port}
    rescue
      create_server(port + 1)
    end

    def timing(label)
      if @stats
        time = Time.now
        value = yield
        puts "#{label}: #{Time.now - time} seconds"
        value
      else
        yield
      end
    end

    def lib_flags(mod)
      libs = mod.library_names
      String.build do |flags|
        commands = [] of String
        if libs.length > 0
          flags << " -Wl"
          libs.each do |libname|
            if libname =~ /^`(.*)`$/
              commands << $1
            else
              flags << ",-l"
              flags << libname
            end
          end
        end
        commands.each do |cmd|
          if @cross_compile
            flags << " `#{cmd} | tr '\\n' ' '`"
          else
            cmdout = system2(cmd)
            if $exit == 0
              cmdout.each do |cmdoutline|
                flags << " #{cmdoutline}"
              end
            else
              raise "Error executing command: #{cmd}"
            end
          end
        end
      end
    end

    class CompilationUnit
      getter compiler

      def initialize(@compiler, type_name, @llvm_mod)
        type_name = "main" if type_name == ""
        @name = type_name.replace do |char|
          if 'a' <= char <= 'z' || 'A' <= char <= 'Z' || '0' <= char <= '9' || char == '_'
            nil
          else
            char.ord.to_s
          end
        end
      end

      def write_bitcode
        write_bitcode(bc_name_new)
      end

      def write_bitcode(output_name)
        @llvm_mod.write_bitcode output_name
      end

      def compile
        output_dir = compiler.output_dir
        bc_name = bc_name()
        bc_name_new = bc_name_new()
        bc_name_opt = "#{output_dir}/#{@name}.opt.bc"
        s_name = "#{output_dir}/#{@name}.s"
        o_name = object_name()
        ll_name = "#{output_dir}/#{@name}.ll"

        must_compile = true

        if !compiler.llc_flags_changed && File.exists?(bc_name) && File.exists?(o_name)
          if FileUtils.cmp(bc_name, bc_name_new)
            File.delete bc_name_new
            must_compile = false
          end
        end

        if must_compile
          File.rename(bc_name_new, bc_name)
          if compiler.release
            system "#{compiler.opt} #{bc_name} -O3 -o #{bc_name_opt}"
            final_bc_name = bc_name_opt
          else
            final_bc_name = bc_name
          end
          system "#{compiler.llc} #{final_bc_name} -o #{s_name} #{compiler.llc_flags}"
          system "#{compiler.clang} -c #{s_name} -o #{o_name}"
        end

        if compiler.dump_ll
          if compiler.release
            system "#{compiler.llvm_dis} #{bc_name_opt} -o #{ll_name}"
          else
            system "#{compiler.llvm_dis} #{bc_name} -o #{ll_name}"
          end
        end
      end

      def object_name
        "#{compiler.output_dir}/#{@name}.o"
      end

      def bc_name
        "#{compiler.output_dir}/#{@name}.bc"
      end

      def bc_name_new
        "#{compiler.output_dir}/#{@name}.new.bc"
      end
    end
  end
end
