require "option_parser"
require "file_utils"
require "socket"
require "colorize"
require "digest/md5"

module Crystal
  @[Flags]
  enum Debug
    LineNumbers
    Variables
    Default     = LineNumbers
  end

  enum Warnings
    All
    None
  end

  # Main interface to the compiler.
  #
  # A Compiler parses source code, type checks it and
  # optionally generates an executable.
  class Compiler
    CC = ENV["CC"]? || "cc"
    CL = "cl"

    # A source to the compiler: its filename and source code.
    record Source,
      filename : String,
      code : String

    # The result of a compilation: the program containing all
    # the type and method definitions, and the parsed program
    # as an ASTNode.
    record Result,
      program : Program,
      node : ASTNode

    # If `true`, doesn't generate an executable but instead
    # creates a `.o` file and outputs a command line to link
    # it in the target machine.
    property cross_compile = false

    # Compiler flags. These will be true when checked in macro
    # code by the `flag?(...)` macro method.
    property flags = [] of String

    # If `true`, the executable will be generated with debug code
    # that can be understood by `gdb` and `lldb`.
    property debug = Debug::Default

    # If `true`, `.ll` files will be generated in the default cache
    # directory for each generated LLVM module.
    property? dump_ll = false

    # Additional link flags to pass to the linker.
    property link_flags : String?

    # Sets the mcpu. Check LLVM docs to learn about this.
    property mcpu : String?

    # Sets the mattr (features). Check LLVM docs to learn about this.
    property mattr : String?

    # If `false`, color won't be used in output messages.
    property? color = true

    # If `true`, skip cleanup process on semantic analysis.
    property? no_cleanup = false

    # If `true`, no executable will be generated after compilation
    # (useful to type-check a prorgam)
    property? no_codegen = false

    # Maximum number of LLVM modules that are compiled in parallel
    property n_threads : Int32 = {% if flag?(:preview_mt) %} 1 {% else %} 8 {% end %}

    # Default prelude file to use. This ends up adding a
    # `require "prelude"` (or whatever name is set here) to
    # the source file to compile.
    property prelude = "prelude"

    # If `true`, runs LLVM optimizations.
    property? release = false

    # Sets the code model. Check LLVM docs to learn about this.
    property mcmodel = LLVM::CodeModel::Default

    # If `true`, generates a single LLVM module. By default
    # one LLVM module is created for each type in a program.
    property? single_module = false

    # A `ProgressTracker` object which tracks compilation progress.
    property progress_tracker = ProgressTracker.new

    # Codegen target to use in the compilation.
    # If not set, asks LLVM the default one for the current machine.
    property codegen_target = Config.default_target

    # If `true`, prints the link command line that is performed
    # to create the executable.
    property? verbose = false

    # If `true`, doc comments are attached to types and methods
    # and can later be used to generate API docs.
    property? wants_doc = false

    # Which kind of warnings wants to be detected.
    property warnings : Warnings = Warnings::All

    # Paths to ignore for warnings detection.
    property warnings_exclude : Array(String) = [] of String

    # If `true` compiler will error if warnings are found.
    property error_on_warnings : Bool = false

    @[Flags]
    enum EmitTarget
      ASM
      OBJ
      LLVM_BC
      LLVM_IR
    end

    # Can be set to a set of flags to emit other files other
    # than the executable file:
    # * asm: assembly files
    # * llvm-bc: LLVM bitcode
    # * llvm-ir: LLVM IR
    # * obj: object file
    property emit : EmitTarget?

    # Base filename to use for `emit` output.
    property emit_base_filename : String?

    # By default the compiler cleans up the default cache directory
    # to keep the most recent 10 directories used. If this is set
    # to `false` that cleanup is not performed.
    property? cleanup = true

    # Default standard output to use in a compilation.
    property stdout : IO = STDOUT

    # Default standard error to use in a compilation.
    property stderr : IO = STDERR

    # Whether to show error trace
    property? show_error_trace = false

    # Whether to link statically
    property? static = false

    # Whether to use llvm ThinLTO for linking
    property thin_lto = false

    # Compiles the given *source*, with *output_filename* as the name
    # of the generated executable.
    #
    # Raises `Crystal::Exception` if there's an error in the
    # source code.
    #
    # Raises `InvalidByteSequenceError` if the source code is not
    # valid UTF-8.
    def compile(source : Source | Array(Source), output_filename : String) : Result
      source = [source] unless source.is_a?(Array)
      program = new_program(source)
      node = parse program, source
      node = program.semantic node, cleanup: !no_cleanup?
      result = codegen program, node, source, output_filename unless @no_codegen

      @progress_tracker.clear
      print_macro_run_stats(program)
      print_codegen_stats(result)

      Result.new program, node
    end

    # Runs the semantic pass on the given source, without generating an
    # executable nor analyzing methods. The returned `Program` in the result will
    # contain all types and methods. This can be useful to generate
    # API docs, analyze type relationships, etc.
    #
    # Raises `Crystal::Exception` if there's an error in the
    # source code.
    #
    # Raises `InvalidByteSequenceError` if the source code is not
    # valid UTF-8.
    def top_level_semantic(source : Source | Array(Source)) : Result
      source = [source] unless source.is_a?(Array)
      program = new_program(source)
      node = parse program, source
      node, processor = program.top_level_semantic(node)

      @progress_tracker.clear
      print_macro_run_stats(program)

      Result.new program, node
    end

    private def new_program(sources)
      program = Program.new
      program.filename = sources.first.filename
      program.cache_dir = CacheDir.instance.directory_for(sources)
      program.codegen_target = codegen_target
      program.target_machine = target_machine
      program.flags << "release" if release?
      program.flags << "debug" unless debug.none?
      program.flags << "static" if static?
      program.flags.concat @flags
      program.wants_doc = wants_doc?
      program.color = color?
      program.stdout = stdout
      program.show_error_trace = show_error_trace?
      program.progress_tracker = @progress_tracker
      program.warnings = @warnings
      program.warnings_exclude = @warnings_exclude.map { |p| File.expand_path p }
      program.error_on_warnings = @error_on_warnings
      program
    end

    private def parse(program, sources : Array)
      @progress_tracker.stage("Parse") do
        nodes = sources.map do |source|
          # We add the source to the list of required file,
          # so it can't be required again
          program.add_to_requires source.filename
          parse(program, source).as(ASTNode)
        end
        nodes = Expressions.from(nodes)

        # Prepend the prelude to the parsed program
        location = Location.new(program.filename, 1, 1)
        nodes = Expressions.new([Require.new(prelude).at(location), nodes] of ASTNode)

        # And normalize
        program.normalize(nodes)
      end
    end

    private def parse(program, source : Source)
      parser = Parser.new(source.code, program.string_pool)
      parser.filename = source.filename
      parser.wants_doc = wants_doc?
      parser.parse
    rescue ex : InvalidByteSequenceError
      stderr.print colorize("Error: ").red.bold
      stderr.print colorize("file '#{Crystal.relative_filename(source.filename)}' is not a valid Crystal source file: ").bold
      stderr.puts ex.message
      exit 1
    end

    private def bc_flags_changed?(output_dir)
      bc_flags_changed = true
      current_bc_flags = "#{@codegen_target}|#{@mcpu}|#{@mattr}|#{@release}|#{@link_flags}|#{@mcmodel}"
      bc_flags_filename = "#{output_dir}/bc_flags"
      if File.file?(bc_flags_filename)
        previous_bc_flags = File.read(bc_flags_filename).strip
        bc_flags_changed = previous_bc_flags != current_bc_flags
      end
      File.write(bc_flags_filename, current_bc_flags)
      bc_flags_changed
    end

    private def codegen(program, node : ASTNode, sources, output_filename)
      llvm_modules = @progress_tracker.stage("Codegen (crystal)") do
        program.codegen node, debug: debug, single_module: @single_module || (!@thin_lto && @release) || @cross_compile || @emit
      end

      output_dir = CacheDir.instance.directory_for(sources)

      bc_flags_changed = bc_flags_changed? output_dir
      target_triple = target_machine.triple

      units = llvm_modules.map do |type_name, info|
        llvm_mod = info.mod
        llvm_mod.target = target_triple
        CompilationUnit.new(self, type_name, llvm_mod, output_dir, bc_flags_changed)
      end

      if @cross_compile
        cross_compile program, units, output_filename
      else
        result = codegen program, units, output_filename, output_dir

        {% if flag?(:darwin) %}
          run_dsymutil(output_filename) unless debug.none?
        {% end %}
      end

      CacheDir.instance.cleanup if @cleanup

      result
    end

    private def run_dsymutil(filename)
      dsymutil = Process.find_executable("dsymutil")
      return unless dsymutil

      @progress_tracker.stage("dsymutil") do
        Process.run(dsymutil, ["--flat", filename])
      end
    end

    private def cross_compile(program, units, output_filename)
      unit = units.first
      llvm_mod = unit.llvm_mod
      object_name = "#{output_filename}.o"

      optimize llvm_mod if @release

      if emit = @emit
        unit.emit(emit, emit_base_filename || output_filename)
      end

      target_machine.emit_obj_to_file llvm_mod, object_name

      stdout.puts linker_command(program, object_name, output_filename, nil)
    end

    private def linker_command(program : Program, object_name, output_filename, output_dir)
      if program.has_flag? "windows"
        if object_name
          object_name = %("#{object_name}")
        else
          object_name = %(%*)
        end

        if (link_flags = @link_flags) && !link_flags.empty?
          link_flags = "/link #{link_flags}"
        end

        %(#{CL} #{object_name} "/Fe#{output_filename}" #{program.lib_flags} #{link_flags})
      else
        if thin_lto
          clang = ENV["CLANG"]? || "clang"
          lto_cache_dir = "#{output_dir}/lto.cache"
          Dir.mkdir_p(lto_cache_dir)
          {% if flag?(:darwin) %}
            cc = ENV["CC"]? || "#{clang} -flto=thin -Wl,-mllvm,-threads=#{n_threads},-cache_path_lto,#{lto_cache_dir},#{@release ? "-mllvm,-O2" : "-mllvm,-O0"}"
          {% else %}
            cc = ENV["CC"]? || "#{clang} -flto=thin -Wl,-plugin-opt,jobs=#{n_threads},-plugin-opt,cache-dir=#{lto_cache_dir} #{@release ? "-O2" : "-O0"}"
          {% end %}
        else
          cc = CC
        end

        if object_name
          object_name = %('#{object_name}')
        else
          object_name = %("${@}")
        end

        link_flags = @link_flags || ""
        link_flags += " -rdynamic"
        link_flags += " -static" if static?

        %(#{cc} #{object_name} -o '#{output_filename}' #{link_flags} #{program.lib_flags})
      end
    end

    private def codegen(program, units : Array(CompilationUnit), output_filename, output_dir)
      object_names = units.map &.object_filename

      target_triple = target_machine.triple
      reused = [] of String

      @progress_tracker.stage("Codegen (bc+obj)") do
        @progress_tracker.stage_progress_total = units.size

        if units.size == 1
          first_unit = units.first
          first_unit.compile
          reused << first_unit.name if first_unit.reused_previous_compilation?

          if emit = @emit
            first_unit.emit(emit, emit_base_filename || output_filename)
          end
        else
          reused = codegen_many_units(program, units, target_triple)
        end
      end

      # We check again because maybe this directory was created in between (maybe with a macro run)
      if Dir.exists?(output_filename)
        error "can't use `#{output_filename}` as output filename because it's a directory"
      end

      output_filename = File.expand_path(output_filename)

      @progress_tracker.stage("Codegen (linking)") do
        Dir.cd(output_dir) do
          linker_command = linker_command(program, nil, output_filename, output_dir)

          process_wrapper(linker_command, object_names) do |command, args|
            Process.run(command, args, shell: true,
              input: Process::Redirect::Close, output: Process::Redirect::Inherit, error: Process::Redirect::Pipe) do |process|
              process.error.each_line(chomp: false) do |line|
                hint_string = colorize("(this usually means you need to install the development package for lib\\1)").yellow.bold
                line = line.gsub(/cannot find -l(\S+)\b/, "cannot find -l\\1 #{hint_string}")
                line = line.gsub(/unable to find library -l(\S+)\b/, "unable to find library -l\\1 #{hint_string}")
                line = line.gsub(/library not found for -l(\S+)\b/, "library not found for -l\\1 #{hint_string}")
                STDERR << line
              end
            end
            $?
          end
        end
      end

      {units, reused}
    end

    private def codegen_many_units(program, units, target_triple)
      all_reused = [] of String

      wants_stats_or_progress = @progress_tracker.stats? || @progress_tracker.progress?

      # If threads is 1 and no stats/progress is needed we can avoid
      # fork/spawn/channels altogether. This is particularly useful for
      # CI because there forking eventually leads to "out of memory" errors.
      if @n_threads == 1
        units.each do |unit|
          unit.compile
          all_reused << unit.name if wants_stats_or_progress && unit.reused_previous_compilation?
        end
        return all_reused
      end

      {% if flag?(:preview_mt) %}
        raise "Cannot fork compiler in multithread mode"
      {% else %}
        jobs_count = 0
        wait_channel = Channel(Array(String)).new(@n_threads)

        units.each_slice(Math.max(units.size // @n_threads, 1)) do |slice|
          jobs_count += 1
          spawn do
            # For stats output we want to count how many previous
            # .o files were reused, mainly to detect performance regressions.
            # Because we fork, we must communicate using a pipe.
            reused = [] of String
            if wants_stats_or_progress
              pr, pw = IO.pipe
              spawn do
                pr.each_line do |line|
                  unit = JSON.parse(line)
                  reused << unit["name"].as_s if unit["reused"].as_bool
                  @progress_tracker.stage_progress += 1
                end
              end
            end

            codegen_process = fork do
              pipe_w = pw
              slice.each do |unit|
                unit.compile
                if pipe_w
                  unit_json = {name: unit.name, reused: unit.reused_previous_compilation?}.to_json
                  pipe_w.puts unit_json
                end
              end
            end
            codegen_process.wait

            if pipe_w = pw
              pipe_w.close
              Fiber.yield
            end

            wait_channel.send reused
          end
        end

        jobs_count.times do
          reused = wait_channel.receive
          all_reused.concat(reused)
        end

        all_reused
      {% end %}
    end

    private def print_macro_run_stats(program)
      return unless @progress_tracker.stats?
      return if program.compiled_macros_cache.empty?

      puts
      puts "Macro runs:"
      program.compiled_macros_cache.each do |filename, compiled_macro_run|
        print " - "
        print filename
        print ": "
        if compiled_macro_run.reused
          print "reused previous compilation (#{compiled_macro_run.elapsed})"
        else
          print compiled_macro_run.elapsed
        end
        puts
      end
    end

    private def print_codegen_stats(result)
      return unless @progress_tracker.stats?
      return unless result

      units, reused = result

      puts
      puts "Codegen (bc+obj):"
      if units.size == reused.size
        puts " - all previous .o files were reused"
      elsif reused.size == 0
        puts " - no previous .o files were reused"
      else
        puts " - #{reused.size}/#{units.size} .o files were reused"
        not_reused = units.reject { |u| reused.includes?(u.name) }
        puts
        puts "These modules were not reused:"
        not_reused.each do |unit|
          puts " - #{unit.original_name} (#{unit.name}.bc)"
        end
      end
    end

    getter(target_machine : LLVM::TargetMachine) do
      @codegen_target.to_target_machine(@mcpu || "", @mattr || "", @release, @mcmodel)
    rescue ex : ArgumentError
      stderr.print colorize("Error: ").red.bold
      stderr.print "llc: "
      stderr.puts ex.message
      exit 1
    end

    protected def optimize(llvm_mod)
      fun_pass_manager = llvm_mod.new_function_pass_manager
      pass_manager_builder.populate fun_pass_manager
      fun_pass_manager.run llvm_mod
      module_pass_manager.run llvm_mod
    end

    @module_pass_manager : LLVM::ModulePassManager?

    private def module_pass_manager
      @module_pass_manager ||= begin
        mod_pass_manager = LLVM::ModulePassManager.new
        pass_manager_builder.populate mod_pass_manager
        mod_pass_manager
      end
    end

    @pass_manager_builder : LLVM::PassManagerBuilder?

    private def pass_manager_builder
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

    private def system(command, args = nil)
      process_wrapper(command, args) do
        ::system(command, args)
        $?
      end
    end

    private def process_wrapper(command, args = nil)
      stdout.puts "#{command} #{args.join " "}" if verbose?

      status = yield command, args

      unless status.success?
        msg = "code: #{status.exit_code}"
        {% unless flag?(:win32) %}
          msg = status.normal_exit? ? "code: #{status.exit_code}" : "signal: #{status.exit_signal} (#{status.exit_signal.value})"
        {% end %}
        code = status.normal_exit? ? status.exit_code : 1
        error "execution of command failed with #{msg}: `#{command}`", exit_code: code
      end
    end

    private def error(msg, exit_code = 1)
      Crystal.error msg, @color, exit_code, stderr: stderr
    end

    private def colorize(obj)
      obj.colorize.toggle(@color)
    end

    # An LLVM::Module with information to compile it.
    class CompilationUnit
      getter compiler
      getter name
      getter original_name
      getter llvm_mod
      getter? reused_previous_compilation = false

      def initialize(@compiler : Compiler, @name : String, @llvm_mod : LLVM::Module,
                     @output_dir : String, @bc_flags_changed : Bool)
        @name = "_main" if @name == ""
        @original_name = @name
        @name = String.build do |str|
          @name.each_char do |char|
            case char
            when 'a'..'z', '0'..'9', '_'
              str << char
            when 'A'..'Z'
              # Because OSX has case insensitive filenames, try to avoid
              # clash of 'a' and 'A' by using 'A-' for 'A'.
              str << char << '-'
            else
              str << char.ord
            end
          end
        end

        if @name.size > 50
          # 17 chars from name + 1 (dash) + 32 (md5) = 50
          @name = "#{@name[0..16]}-#{Digest::MD5.hexdigest(@name)}"
        end
      end

      def compile
        if compiler.thin_lto
          compile_to_thin_lto
        else
          compile_to_object
        end
      end

      private def compile_to_thin_lto
        {% unless LibLLVM::IS_38 || LibLLVM::IS_39 %}
          # Here too, we first compile to a temporary file and then rename it
          llvm_mod.write_bitcode_with_summary_to_file(temporary_object_name)
          File.rename(temporary_object_name, object_name)
          @reused_previous_compilation = false
          dump_llvm_ir
        {% else %}
          raise {{ "ThinLTO is not available in LLVM #{LibLLVM::VERSION}".stringify }}
        {% end %}
      end

      private def compile_to_object
        bc_name = self.bc_name
        object_name = self.object_name
        temporary_object_name = self.temporary_object_name

        # To compile a file we first generate a `.bc` file and then
        # create an object file from it. These `.bc` files are stored
        # in the cache directory.
        #
        # On a next compilation of the same project, and if the compile
        # flags didn't change (a combination of the target triple, mcpu,
        # release and link flags, amongst others), we check if the new
        # `.bc` file is exactly the same as the old one. In that case
        # the `.o` file will also be the same, so we simply reuse the
        # old one. Generating an `.o` file is what takes most time.
        #
        # However, instead of directly generating the final `.o` file
        # from the `.bc` file, we generate it to a temporary name (`.o.tmp`)
        # and then we rename that file to `.o`. We do this because the compiler
        # could be interrupted while the `.o` file is being generated, leading
        # to a corrupted file that later would cause compilation issues.
        # Moving a file is an atomic operation so no corrupted `.o` file should
        # be generated.

        must_compile = true
        can_reuse_previous_compilation =
          !compiler.emit && !@bc_flags_changed && File.exists?(bc_name) && File.exists?(object_name)

        memory_buffer = llvm_mod.write_bitcode_to_memory_buffer

        if can_reuse_previous_compilation
          memory_io = IO::Memory.new(memory_buffer.to_slice)
          changed = File.open(bc_name) { |bc_file| !FileUtils.cmp(bc_file, memory_io) }

          # If the user cancelled a previous compilation
          # it might be that the .o file is empty
          if !changed && File.size(object_name) > 0
            must_compile = false
            memory_buffer.dispose
            memory_buffer = nil
          else
            # We need to compile, so we'll write the memory buffer to file
          end
        end

        # If there's a memory buffer, it means we must create a .o from it
        if memory_buffer
          # Create the .bc file (for next compilations)
          File.write(bc_name, memory_buffer.to_slice)
          memory_buffer.dispose
        end

        if must_compile
          compiler.optimize llvm_mod if compiler.release?
          compiler.target_machine.emit_obj_to_file llvm_mod, temporary_object_name
          File.rename(temporary_object_name, object_name)
        else
          @reused_previous_compilation = true
        end

        dump_llvm_ir
      end

      private def dump_llvm_ir
        llvm_mod.print_to_file ll_name if compiler.dump_ll?
      end

      def emit(emit_target : EmitTarget, output_filename)
        if emit_target.asm?
          compiler.target_machine.emit_asm_to_file llvm_mod, "#{output_filename}.s"
        end
        if emit_target.llvm_bc?
          FileUtils.cp(bc_name, "#{output_filename}.bc")
        end
        if emit_target.llvm_ir?
          llvm_mod.print_to_file "#{output_filename}.ll"
        end
        if emit_target.obj?
          FileUtils.cp(object_name, "#{output_filename}.o")
        end
      end

      def object_name
        Crystal.relative_filename("#{@output_dir}/#{object_filename}")
      end

      def object_filename
        "#{@name}.o"
      end

      def temporary_object_name
        Crystal.relative_filename("#{@output_dir}/#{object_filename}.tmp")
      end

      def bc_name
        "#{@output_dir}/#{@name}.bc"
      end

      def bc_name_new
        "#{@output_dir}/#{@name}.new.bc"
      end

      def ll_name
        "#{@output_dir}/#{@name}.ll"
      end
    end
  end
end
