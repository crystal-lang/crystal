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

    record Source, filename, code
    record Result, program, node, original_node

    property cross_compile_flags
    property flags
    property? debug
    property? dump_ll
    property link_flags
    property mcpu
    property? color
    property? no_codegen
    property n_threads
    property prelude
    property? release
    property? single_module
    property? stats
    property target_triple
    property? verbose
    property? wants_doc
    property emit
    property original_output_filename

    def initialize
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
    end

    def compile(source : Source, output_filename)
      compile [source], output_filename
    end

    def compile(sources : Array(Source), output_filename)
      program = Program.new
      program.target_machine = target_machine
      if cross_compile_flags = @cross_compile_flags
        program.flags = cross_compile_flags
      end
      program.flags << "release" if @release
      program.flags.merge @flags
      program.wants_doc = wants_doc?
      program.color = color?

      @link_flags = "#{@link_flags} -rdynamic"

      node, original_node = parse program, sources
      node = infer_type program, node
      codegen program, node, sources, output_filename unless @no_codegen

      Result.new program, node, original_node
    end

    def add_flag(flag)
      @flags << flag
    end

    private def parse(program, sources)
      node = nil
      require_node = nil

      timing("Parse") do
        nodes = sources.map do |source|
          program.add_to_requires source.filename
          parse source
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

    private def parse(source)
      parser = Parser.new(source.code)
      parser.filename = source.filename
      parser.wants_doc = wants_doc?
      parser.parse
    rescue ex : InvalidByteSequenceError
      print colorize("Error: ").red.bold
      print colorize("file '#{Crystal.relative_filename(source.filename)}' is not a valid Crystal source file: ").bold
      puts "#{ex.message}"
      exit 1
    end

    private def infer_type(program, node)
      program.infer_type node, @stats
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

    private def codegen(program, node, sources, output_filename)
      lib_flags = program.lib_flags

      llvm_modules = timing("Codegen (crystal)") do
        program.codegen node, debug: @debug, single_module: @single_module || @release || @cross_compile_flags || @emit, expose_crystal_main: false
      end

      if @cross_compile_flags
        output_dir = "."
      else
        output_dir = File.join(Config.cache_dir, sources.first.filename)
      end

      Dir.mkdir_p(output_dir)

      bc_flags_changed = check_bc_flags_changed output_dir

      units = llvm_modules.map do |type_name, llvm_mod|
        CompilationUnit.new(self, type_name, llvm_mod, output_dir, bc_flags_changed)
      end

      if @cross_compile_flags
        cross_compile program, units, lib_flags, output_filename
      else
        codegen units, lib_flags, output_filename
      end
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

    private def codegen(units, lib_flags, output_filename)
      object_names = units.map &.object_name
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

          codegen_single_unit(first_unit, target_triple, multithreaded)

          if emit = @emit
            first_unit.emit(emit, original_output_filename || output_filename)
          end
        else
          codegen_many_units(units, target_triple, multithreaded)
        end
      end

      # We check again because maybe this directory was created in between (maybe with a macro run)
      if Dir.exists?(output_filename)
        error "can't use `#{output_filename}` as output filename because it's a directory"
      end

      timing("Codegen (linking)") do
        system %(#{CC} -o "#{output_filename}" "${@}" #{@link_flags} #{lib_flags}), object_names
      end
    end

    private def codegen_many_units(units, target_triple, multithreaded)
      jobs_count = 0

      while unit = units.pop?
        fork { codegen_single_unit(unit, target_triple, multithreaded) }

        jobs_count += 1

        if jobs_count >= @n_threads
          LibC.waitpid(-1, out stat_loc, 0)
          jobs_count -= 1
        end
      end

      while jobs_count > 0
        LibC.waitpid(-1, out stat_loc_2, 0)
        jobs_count -= 1
      end
    end

    private def codegen_single_unit(unit, target_triple, multithreaded)
      unit.llvm_mod.target = target_triple
      ifdef x86_64
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
      puts command if verbose?

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
      getter compiler
      getter llvm_mod

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
        Crystal.relative_filename("#{@output_dir}/#{@name}.o")
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

  def self.error(msg, color, exit_code = 1)
    STDERR.print "Error: ".colorize.toggle(color).red.bold
    STDERR.puts msg.colorize.toggle(color).bright
    exit exit_code
  end

  def self.relative_filename(filename : String)
    dir = Dir.current
    if filename.starts_with?(dir)
      filename = filename[dir.size..-1]
      if filename.starts_with? "/"
        ".#{filename}"
      else
        "./#{filename}"
      end
    else
      filename
    end
  end

  def self.relative_filename(filename)
    filename
  end

  def self.timing(label, stats)
    if stats
      time = Time.now
      value = yield
      puts "%-34s %s" % {"#{label}:", Time.now - time}
      value
    else
      yield
    end
  end
end
