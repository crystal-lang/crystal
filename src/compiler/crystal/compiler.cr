require "option_parser"
require "thread"
require "file_utils"
require "socket"
require "net/http/common/common"
require "colorize"

module Crystal
  class Compiler
    include Crystal

    DataLayout32 = "e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-v64:64:64-v128:128:128-a0:0:64-f80:32:32-n8:16:32"
    DataLayout64 = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64"

    getter dump_ll
    getter debug
    property release
    getter bc_flags_changed
    getter cross_compile
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
      @command = nil
      @cross_compile = nil
      @target_triple = nil
      @mcpu = nil
      @bc_flags_changed = true
      @prelude = "prelude"
      @n_threads = 8.to_i32
      @browser = false
      @single_module = false
      @verbose = false
      @link_flags = nil
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
        opts.on("--link-flags FLAGS", "Additional flags to pass to the linker") do |link_flags|
          @link_flags = link_flags
        end
        opts.on("--mcpu CPU", "Target specific cpu type") do |cpu|
          @mcpu = cpu
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
        opts.on("--target TRIPLE", "Target triple") do |triple|
          @target_triple = triple
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
        program.target_machine = target_machine
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

        lib_flags = lib_flags(program)

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
          llvm_mod = units.first.llvm_mod
          o_name = "#{output_filename}.o"

          if program.has_flag?("x86_64")
            llvm_mod.data_layout = DataLayout64
          else
            llvm_mod.data_layout = DataLayout32
          end

          if @release
            optimize llvm_mod
          end

          target_machine.emit_obj_to_file llvm_mod, o_name

          puts "cc #{o_name} -o #{output_filename} #{lib_flags} #{@link_flags}"
        else
          multithreaded = LLVM.start_multithreaded

          # First write bitcodes: it breaks if we paralellize it
          unless multithreaded
            timing("Codegen (bitcode)") do
              units.each &.write_bitcode
            end
          end

          current_bc_flags = "#{@target_triple}|#{@mcpu}|#{@release}|#{@link_flags}"
          bc_flags_filename = "#{output_dir}/bc_flags"
          if File.exists?(bc_flags_filename)
            previous_bc_flags = File.read(bc_flags_filename).strip
            @bc_flags_changed = previous_bc_flags != current_bc_flags
          end

          msg = multithreaded ? "Codegen (bc+obj)" : "Codegen (obj)"
          target_triple = target_machine.triple

          jobs_count = 0

          timing(msg) do
            while unit = units.pop?
              fork do
                unit.llvm_mod.target = target_triple
                ifdef x86_64
                  unit.llvm_mod.data_layout = DataLayout64
                else
                  unit.llvm_mod.data_layout = DataLayout32
                end
                unit.write_bitcode if multithreaded
                unit.compile
              end

              jobs_count += 1

              if jobs_count >= @n_threads
                C.waitpid(-1, out stat_loc, 0)
                jobs_count -= 1
              end
            end

            while jobs_count > 0
              C.waitpid(-1, out stat_loc, 0)
              jobs_count -= 1
            end
          end

          timing("Codegen (clang)") do
            system "cc -o #{output_filename} #{object_names.join " "} #{lib_flags} #{@link_flags}"
          end

          File.open(bc_flags_filename, "w") do |file|
            file.puts current_bc_flags
          end

          if @run
            # TODO: fix system to make output flush on newline if it's a tty
            exit_status = C.system("#{output_filename} #{run_args.map(&.inspect).join " "}")
            if exit_status != 0
              puts "Program terminated abnormally with error code: #{exit_status}"
            end
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

    def target_machine
      @target_machine ||= begin
        triple = @target_triple || TargetMachine::HOST_TARGET_TRIPLE
        TargetMachine.create(triple, @mcpu || "", @release)
      end
    end

    def optimize(llvm_mod)
      fun_pass_manager = llvm_mod.new_function_pass_manager
      if data_layout = target_machine.data_layout
        fun_pass_manager.add_target_data data_layout
      end
      pass_manager_builder.populate fun_pass_manager
      fun_pass_manager.run llvm_mod

      module_pass_manager.run llvm_mod
    end

    def module_pass_manager
      @module_pass_manager ||= begin
        mod_pass_manager = LLVM::ModulePassManager.new
        if data_layout = target_machine.data_layout
          mod_pass_manager.add_target_data data_layout
        end
        pass_manager_builder.populate mod_pass_manager
        mod_pass_manager
      end
    end

    def pass_manager_builder
      @pass_manager_builder ||= begin
        registry = LLVM::PassRegistry.instance
        registry.initialize_all

        builder = LLVM::PassManagerBuilder.new
        builder.opt_level = 3
        builder.size_level = 0
        builder.use_inliner_with_threshold = 275
        builder
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
            response = HTTP::Response.new(200, html, {"Content-Type" => "text/html"})
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

      success = ::system(command)
      unless success
        print "Error: ".colorize.red.bold
        puts "execution of command failed with code: #{$?.exit}: `#{command}`".colorize.bright
        exit 3
      end
      success
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
      library_path = ["/usr/lib", "/usr/local/lib"]

      String.build do |flags|
        mod.link_attributes.reverse_each do |attr|
          if ldflags = attr.ldflags
            flags << " "
            flags << ldflags
          end

          if libname = attr.lib
            if libflags = pkg_config_flags(libname, attr.static?, library_path)
              flags << " " << libflags
            elsif attr.static? && (static_lib = find_static_lib(libname, library_path))
              flags << " " << static_lib
            else
              flags << " -l" << libname
            end
          end

          if framework = attr.framework
            flags << " -framework " << framework
          end
        end
      end
    end

    def pkg_config_flags(libname, static, library_path)
      if ::system("pkg-config #{libname}")
        if static
          flags = [] of String
          `pkg-config #{libname} --libs --static`.split.each do |cfg|
            if cfg.starts_with?("-L")
              library_path << cfg[2 .. -1]
            elsif cfg.starts_with?("-l")
              flags << (find_static_lib(cfg[2 .. -1], library_path) || cfg)
            else
              flags << cfg
            end
          end
          flags.join " "
        else
          `pkg-config #{libname} --libs`.chomp
        end
      end
    end

    def find_static_lib(libname, library_path)
      library_path.each do |libdir|
        static_lib = "#{libdir}/lib#{libname}.a"
        return static_lib if File.exists?(static_lib)
      end
      nil
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
            char.ord
          end
        end
      end

      def write_bitcode
        write_bitcode(bc_name_new)
      end

      def write_bitcode(output_name)
        @llvm_mod.write_bitcode output_name unless has_long_name?
      end

      def compile
        output_dir = compiler.output_dir
        bc_name = bc_name()
        bc_name_new = bc_name_new()
        o_name = object_name()
        ll_name = "#{output_dir}/#{@name}.ll"

        must_compile = true

        if !has_long_name? && !compiler.bc_flags_changed && File.exists?(bc_name) && File.exists?(o_name)
          if FileUtils.cmp(bc_name, bc_name_new)
            File.delete bc_name_new
            must_compile = false
          end
        end

        if must_compile
          File.rename(bc_name_new, bc_name) unless has_long_name?
          if compiler.release
            compiler.optimize @llvm_mod
          end
          compiler.target_machine.emit_obj_to_file @llvm_mod, o_name
        end

        if compiler.dump_ll
          llvm_mod.print_to_file ll_name
        end
      end

      def object_name
        if has_long_name?
          "#{compiler.output_dir}/#{object_id}.o"
        else
          "#{compiler.output_dir}/#{@name}.o"
        end
      end

      def bc_name
        "#{compiler.output_dir}/#{@name}.bc"
      end

      def bc_name_new
        "#{compiler.output_dir}/#{@name}.new.bc"
      end

      def has_long_name?
        @name.length >= 240
      end
    end
  end
end
