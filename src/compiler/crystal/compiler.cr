require "option_parser"
require "thread"
require "file_utils"
require "socket"
require "net/http"
require "colorize"

module Crystal
  class Compiler
    include Crystal

    DataLayout32 = "e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-v64:64:64-v128:128:128-a0:0:64-f80:32:32-n8:16:32"
    DataLayout64 = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64"

    getter config
    getter llc
    getter opt
    getter clang
    getter llvm_dis
    getter dump_ll
    getter debug
    property release
    getter llc_flags
    getter llc_flags_changed
    getter cross_compile
    getter uses_gcc
    getter verbose
    getter! output_dir
    property output_filename

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
      @prelude = "prelude"
      @n_threads = 8.to_i32
      @browser = false
      @single_module = false
      @uses_gcc = false
      @verbose = false

      @config = LLVMConfig.new
      @llc = @config.bin "llc"
      @opt = @config.bin "opt"
      @clang = @config.bin "clang"
      @llvm_dis = @config.bin "llvm-dis"

      check_clang_or_gcc
    end

    def check_clang_or_gcc
      unless File.exists?(@clang)
        clang = Program.exec "which gcc"
        if clang
          @clang = clang
          @uses_gcc = true
        else
          puts "Could not find a C compiler. Install clang (3.3) or gcc."
          exit 1
        end
      end
    end

    def process_options(options = ARGV)
      begin
        options_parser, inline_exp, filenames, arguments = process_options_internal(options)
      rescue ex : OptionParser::Exception
        print "Error: ".colorize.red.bold
        puts ex.message.colorize.bold
        exit 1
      end

      if inline_exp
        sources = [Source.new("-e", inline_exp)] of Source
        @run = true
      else
        if filenames.length == 0
          puts options_parser
          exit 1
        end

        sources = filenames.map do |filename|
          unless File.exists?(filename)
            puts "File #{filename} does not exist"
            exit 1
          end
          filename = File.expand_path(filename)
          Source.new(filename, File.read(filename))
        end
      end

      compile sources, arguments
    end

    def process_options_internal(options)
      inline_exp = nil
      filenames = nil
      arguments = nil

      option_parser = OptionParser.parse(options) do |opts|
        opts.banner = "Usage: crystal [switches] [--] [programfile] [arguments]"
        opts.on("--browser", "Opens an http server to browse the code") do
          @browser = true
        end
        opts.on("--cross-compile flags", "cross-compile") do |cross_compile|
          @cross_compile = cross_compile
        end
        opts.on("-d", "--debug", "Add symbolic debug info") do
          @debug = true
        end
        opts.on("-e 'command'", "One line script. Omit [programfile]") do |the_inline_exp|
          inline_exp = the_inline_exp
        end
        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit 1
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
          @n_threads = n_threads.to_i
        end
        opts.on("-v", "--version", "Print Crystal version") do
          puts "Crystal #{Crystal.version_string}"
          exit
        end
        opts.on("--verbose", "Display executed commands") do
          @verbose = true
        end
        opts.unknown_args do |before, after|
          filenames = before
          arguments = after
        end
      end
      {option_parser, inline_exp, filenames.not_nil!, arguments.not_nil!}
    end

    def compile(source : Source, run_args = [] of String)
      compile [source], run_args
    end

    def compile(sources : Array(Source), run_args = [] of String)
      output_filename = @output_filename
      unless output_filename
        if @run
          output_filename = "#{ENV["TMPDIR"]? || "/tmp"}/.crystal-run.XXXXXX"
          tmp_fd = C.mkstemp output_filename
          raise "Error creating temp file #{output_filename}" if tmp_fd == -1
          C.close tmp_fd
        else
          output_filename = File.basename(sources.first.filename, File.extname(sources.first.filename))
        end
      end

      begin
        program = Program.new
        if cross_compile = @cross_compile
          program.flags = cross_compile
        end

        if @release
          program.add_flag "release"
        end

        node = nil
        require_node = nil

        timing("Parse") do
          nodes = sources.map do |source|
            program.add_to_requires source.filename

            parser = Parser.new(source.code)
            parser.filename = source.filename
            parser.parse
          end
          node = Expressions.from(nodes)

          require_node = Require.new(@prelude)
          require_node = program.normalize(require_node)

          node = program.normalize(node)
        end

        node = node.not_nil!
        require_node = require_node.not_nil!

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
          program.build node, debug: @debug, single_module: @single_module || @release || @cross_compile
        end

        cache_filename = sources.first.filename

        if @cross_compile
          output_dir = "."
        else
          output_dir = ".crystal/#{cache_filename}"
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

          if program.has_flag?("x86_64")
            compilation_unit.llvm_mod.data_layout = DataLayout64
          else
            compilation_unit.llvm_mod.data_layout = DataLayout32
          end

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
          target_triple = Crystal::TargetMachine::DEFAULT.triple

          timing(msg) do
            threads = Array.new(@n_threads) do
              Thread.new do
                while unit = mutex.synchronize { units.shift? }
                  unit.llvm_mod.target = target_triple
                  ifdef x86_64
                    unit.llvm_mod.data_layout = DataLayout64
                  else
                    unit.llvm_mod.data_layout = DataLayout32
                  end
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
            errcode = C.system("#{output_filename} #{run_args.map(&.inspect).join " "}")
            puts "Program terminated abnormally with error code: #{errcode}" if errcode != 0
            File.delete output_filename
          end
        end
      rescue ex : Crystal::Exception
        puts ex
        exit 1
      rescue ex
        puts ex
        ex.backtrace.each do |frame|
          puts frame
        end
        puts
        print "Error: ".colorize.red.bold
        puts "you've found a bug in the Crystal compiler. Please open an issue: https://github.com/manastech/crystal/issues".colorize.bright
        exit 2
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
          if request = HTTP::Request.from_io(sock)
            html = browser.handle(request.path)
            response = HTTP::Response.new("HTTP/1.1", 200, "OK", {"Content-Type" => "text/html"}, html)
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

    def system(command)
      puts command if verbose
      exit_code = ::system(command)
      if exit_code != 0
        print "Error: ".colorize.red.bold
        puts "execution of command failed with code: #{exit_code}: `#{command}`".colorize.bright
        exit 3
      end
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
        flags << ".build/libgc.a -lpthread"
        if libs.length > 0
          libs.reverse_each do |libname|
            if libname =~ /^`(.*)`$/
              cmd = $1
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
            else
              flags << " -l" << libname
            end
          end
        end
      end
    end

    class CompilationUnit
      getter compiler
      getter llvm_mod

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

      def system(command)
        compiler.system command
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
            system "#{compiler.llc} #{bc_name_opt} -o #{s_name} #{compiler.llc_flags}"
            system "#{compiler.clang} -c #{s_name} -o #{o_name}"
          elsif compiler.uses_gcc
            system "#{compiler.llc} #{bc_name} -filetype=obj -o #{o_name} #{compiler.llc_flags}"
          else
            system "#{compiler.clang} -c #{bc_name} -o #{o_name}"
            # Crystal::TargetMachine::DEFAULT.emit_obj_to_file @llvm_mod, o_name
          end
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
