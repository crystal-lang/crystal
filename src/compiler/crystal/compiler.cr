require "option_parser"
require "file_utils"
require "socket"
require "colorize"
require "crypto/md5"

module Crystal
  class Compiler
    DataLayout32 = "e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-v64:64:64-v128:128:128-a0:0:64-f80:32:32-n8:16:32"
    DataLayout64 = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64"

    CC = ENV["CC"]? || "cc"

    record Source,
      filename : String,
      code : String

    record Result,
      program : Program,
      node : ASTNode,
      original_node : ASTNode

    property cross_compile : Bool
    property flags : Array(String)
    property? debug : Bool
    property? dump_ll : Bool
    property link_flags : String?
    property mcpu : String?
    property? color : Bool
    property? no_codegen : Bool
    property n_threads : Int32
    property prelude : String
    property? release : Bool
    property? single_module : Bool
    property? stats : Bool
    property target_triple : String?
    property? verbose : Bool
    property? wants_doc : Bool
    property emit : Array(String)?
    property original_output_filename : String?
    property? cleanup : Bool?

    @target_machine : LLVM::TargetMachine?
    @pass_manager_builder : LLVM::PassManagerBuilder?
    @module_pass_manager : LLVM::ModulePassManager?

    def initialize
      @cross_compile = false
      @debug = false
      @dump_ll = false
      @color = true
      @no_codegen = false
      @n_threads = 8.to_i32
      @prelude = "prelude"
      @release = false
      @single_module = false
      @stats = false
      @verbose = false
      @wants_doc = false
      @flags = [] of String
      @cleanup = true
    end

    def compile(source : Source, output_filename)
      compile [source], output_filename
    end

    def compile(sources : Array(Source), output_filename)
      program = new_program(sources)
      node, original_node = parse program, sources
      node = program.infer_type node, @stats
      codegen program, node, sources, output_filename unless @no_codegen
      Result.new program, node, original_node
    end

    def type_top_level(source : Source)
      type_top_level [source]
    end

    def type_top_level(sources : Array(Source))
      program = new_program(sources)
      node, original_node = parse program, sources
      node = program.infer_type_top_level(node, @stats)
      Result.new program, node, original_node
    end

    private def new_program(sources)
      program = Program.new
      program.cache_dir = CacheDir.instance.directory_for(sources)
      program.target_machine = target_machine
      program.flags << "release" if @release
      program.flags.merge @flags
      program.wants_doc = wants_doc?
      program.color = color?
      program
    end

    def add_flag(flag)
      @flags << flag
    end

    private def parse(program, sources : Array)
      node = nil
      require_node = nil

      timing("Parse") do
        nodes = sources.map do |source|
          program.add_to_requires source.filename
          parse(program, source).as(ASTNode)
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

      {node, original_node}
    end

    private def parse(program, source : Source)
      parser = Parser.new(source.code, program.string_pool)
      parser.filename = source.filename
      parser.wants_doc = wants_doc?
      parser.parse
    rescue ex : InvalidByteSequenceError
      print colorize("Error: ").red.bold
      print colorize("file '#{Crystal.relative_filename(source.filename)}' is not a valid Crystal source file: ").bold
      puts "#{ex.message}"
      exit 1
    end

    private def check_bc_flags_changed(output_dir)
      bc_flags_changed = true
      current_bc_flags = "#{@target_triple}|#{@mcpu}|#{@release}|#{@link_flags}"
      bc_flags_filename = "#{output_dir}/bc_flags"
      if File.file?(bc_flags_filename)
        previous_bc_flags = File.read(bc_flags_filename).strip
        bc_flags_changed = previous_bc_flags != current_bc_flags
      end
      File.open(bc_flags_filename, "w") do |file|
        file.puts current_bc_flags
      end
      bc_flags_changed
    end

    private def codegen(program : Program, node, sources, output_filename)
      @link_flags = "#{@link_flags} -rdynamic"

      lib_flags = program.lib_flags

      llvm_modules = timing("Codegen (crystal)") do
        program.codegen node, debug: @debug, single_module: @single_module || @release || @cross_compile || @emit, expose_crystal_main: false
      end

      cache_dir = CacheDir.instance

      if @cross_compile
        output_dir = "."
      else
        output_dir = cache_dir.directory_for(sources)
      end

      bc_flags_changed = check_bc_flags_changed output_dir

      units = llvm_modules.map do |type_name, llvm_mod|
        CompilationUnit.new(self, type_name, llvm_mod, output_dir, bc_flags_changed)
      end

      if @cross_compile
        cross_compile program, units, lib_flags, output_filename
      else
        codegen program, units, lib_flags, output_filename, output_dir
      end

      cache_dir.cleanup if @cleanup
    end

    private def cross_compile(program, units, lib_flags, output_filename)
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

      if dump_ll?
        llvm_mod.print_to_file o_name.gsub(/\.o/, ".ll")
      end

      target_machine.emit_obj_to_file llvm_mod, o_name

      puts "#{CC} #{o_name} -o #{output_filename} #{@link_flags} #{lib_flags}"
    end

    private def codegen(program, units : Array(CompilationUnit), lib_flags, output_filename, output_dir)
      object_names = units.map &.object_filename
      multithreaded = LLVM.start_multithreaded

      # First write bitcodes: it breaks if we paralellize it
      unless multithreaded
        timing("Codegen (cyrstal)") do
          units.each &.write_bitcode
        end
      end

      msg = multithreaded ? "Codegen (bc+obj)" : "Codegen (obj)"
      target_triple = target_machine.triple

      timing(msg) do
        if units.size == 1
          first_unit = units.first

          codegen_single_unit(program, first_unit, target_triple, multithreaded)

          if emit = @emit
            first_unit.emit(emit, original_output_filename || output_filename)
          end
        else
          codegen_many_units(program, units, target_triple, multithreaded)
        end
      end

      # We check again because maybe this directory was created in between (maybe with a macro run)
      if Dir.exists?(output_filename)
        error "can't use `#{output_filename}` as output filename because it's a directory"
      end

      output_filename = File.expand_path(output_filename)

      timing("Codegen (linking)") do
        Dir.cd(output_dir) do
          system %(#{CC} -o "#{output_filename}" "${@}" #{@link_flags} #{lib_flags}), object_names
        end
      end
    end

    private def codegen_many_units(program, units, target_triple, multithreaded)
      jobs_count = 0
      wait_channel = Channel(Nil).new(@n_threads)

      while unit = units.pop?
        fork_and_codegen_single_unit(program, unit, target_triple, multithreaded, wait_channel)
        jobs_count += 1

        if jobs_count >= @n_threads
          wait_channel.receive
          jobs_count -= 1
        end
      end

      while jobs_count > 0
        wait_channel.receive
        jobs_count -= 1
      end
    end

    private def fork_and_codegen_single_unit(program, unit, target_triple, multithreaded, wait_channel)
      spawn do
        codegen_process = fork { codegen_single_unit(program, unit, target_triple, multithreaded) }
        codegen_process.wait
        wait_channel.send nil
      end
    end

    private def codegen_single_unit(program, unit, target_triple, multithreaded)
      unit.llvm_mod.target = target_triple
      if program.has_flag?("x86_64")
        unit.llvm_mod.data_layout = DataLayout64
      else
        unit.llvm_mod.data_layout = DataLayout32
      end
      unit.write_bitcode if multithreaded
      unit.compile
    end

    def target_machine
      @target_machine ||= begin
        triple = @target_triple || LLVM.default_target_triple
        TargetMachine.create(triple, @mcpu || "", @release)
      end
    rescue ex : ArgumentError
      print colorize("Error: ").red.bold
      print "llc: "
      puts "#{ex.message}"
      exit 1
    end

    def optimize(llvm_mod)
      fun_pass_manager = llvm_mod.new_function_pass_manager
      fun_pass_manager.add_target_data target_machine.data_layout
      pass_manager_builder.populate fun_pass_manager
      fun_pass_manager.run llvm_mod

      module_pass_manager.run llvm_mod
    end

    private def module_pass_manager
      @module_pass_manager ||= begin
        mod_pass_manager = LLVM::ModulePassManager.new
        mod_pass_manager.add_target_data target_machine.data_layout
        pass_manager_builder.populate mod_pass_manager
        mod_pass_manager
      end
    end

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
      puts "#{command} #{args.join " "}" if verbose?

      ::system(command, args)
      unless $?.success?
        msg = $?.normal_exit? ? "code: #{$?.exit_code}" : "signal: #{$?.exit_signal} (#{$?.exit_signal.value})"
        code = $?.normal_exit? ? $?.exit_code : 1
        error "execution of command failed with #{msg}: `#{command}`", exit_code: code
      end
    end

    private def error(msg, exit_code = 1)
      Crystal.error msg, @color, exit_code
    end

    private def timing(label)
      Crystal.timing(label, @stats) do
        yield
      end
    end

    private def colorize(obj)
      obj.colorize.toggle(@color)
    end

    class CompilationUnit
      getter compiler : Compiler
      getter llvm_mod : LLVM::Module

      @name : String
      @output_dir : String
      @bc_flags_changed : Bool

      def initialize(@compiler, type_name, @llvm_mod, @output_dir, @bc_flags_changed)
        type_name = "_main" if type_name == ""
        @name = type_name.gsub do |char|
          case char
          when 'a'..'z', 'A'..'Z', '0'..'9', '_'
            char
          else
            char.ord
          end
        end

        if @name.size > 50
          # 17 chars from name + 1 (dash) + 32 (md5) = 50
          @name = "#{@name[0..16]}-#{Crypto::MD5.hex_digest(@name)}"
        end
      end

      def write_bitcode
        write_bitcode(bc_name_new)
      end

      def write_bitcode(output_name)
        llvm_mod.write_bitcode output_name
      end

      def compile
        bc_name = bc_name()
        bc_name_new = bc_name_new()
        o_name = object_name()

        must_compile = true

        if !compiler.emit && !@bc_flags_changed && File.exists?(bc_name) && File.exists?(o_name)
          if FileUtils.cmp(bc_name, bc_name_new)
            # If the user cancelled a previous compilation it might be that the .o file is empty
            if File.size(o_name) > 0
              File.delete bc_name_new
              must_compile = false
            end
          end
        end

        if must_compile
          File.rename(bc_name_new, bc_name)
          if compiler.release?
            compiler.optimize llvm_mod
          end
          compiler.target_machine.emit_obj_to_file llvm_mod, o_name
        end

        if compiler.dump_ll?
          llvm_mod.print_to_file ll_name
        end
      end

      def emit(values : Array, output_filename)
        values.each do |value|
          emit value, output_filename
        end
      end

      def emit(value : String, output_filename)
        case value
        when "asm"
          compiler.target_machine.emit_asm_to_file llvm_mod, "#{output_filename}.s"
        when "llvm-bc"
          `cp #{bc_name} #{output_filename}.bc`
        when "llvm-ir"
          llvm_mod.print_to_file "#{output_filename}.ll"
        when "obj"
          `cp #{object_name} #{output_filename}.o`
        end
      end

      def object_name
        Crystal.relative_filename("#{@output_dir}/#{object_filename}")
      end

      def object_filename
        "#{@name}.o"
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
