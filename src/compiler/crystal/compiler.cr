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

    property cross_compile_flags : String?
    property flags : Array(String)
    property? debug : Bool
    property? dump_ll : Bool
    property link_flags : String?
    property mcpu : String?
    property? color : Bool
    property? no_codegen : Bool
    property n_threads : Int32
    property n_concurrent : Int32
    property prelude : String
    property? release : Bool
    property? single_module : Bool
    property? stats : Bool
    property target_triple : String?
    property? verbose : Bool
    property? wants_doc : Bool
    property emit : Array(String)?
    property original_output_filename : String?

    @target_machine : LLVM::TargetMachine?
    @pass_manager_builder : LLVM::PassManagerBuilder?
    @module_pass_manager : LLVM::ModulePassManager?

    def initialize
      @debug = false
      @dump_ll = false
      @color = true
      @no_codegen = false
      @n_threads = 8.to_i32
      @n_concurrent = 1000_i32
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
      program = new_program
      node, original_node = parse program, sources
      node = program.infer_type node, @stats
      codegen program, node, sources, output_filename unless @no_codegen
      Result.new program, node, original_node
    end

    def type_top_level(source : Source)
      type_top_level [source]
    end

    def type_top_level(sources : Array(Source))
      program = new_program
      node, original_node = parse program, sources
      node = program.infer_type_top_level(node, @stats)
      Result.new program, node, original_node
    end

    private def new_program
      program = Program.new
      program.target_machine = target_machine
      if cross_compile_flags = @cross_compile_flags
        program.flags = cross_compile_flags
      end
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

    private def codegen(program : Program, node, sources, output_filename)
      @link_flags = "#{@link_flags} -rdynamic"
      bc_flags_md5 = Crypto::MD5.hex_digest "#{@target_triple}#{@mcpu}#{@release}#{@link_flags}"

      lib_flags = program.lib_flags

      llvm_modules = timing("Codegen (crystal)") do
        program.codegen node, debug: @debug, single_module: @single_module || @release || @cross_compile_flags || @emit, expose_crystal_main: false
      end

      cache_dir = CacheDir.instance

      if @cross_compile_flags
        output_dir = "."
      else
        output_dir = cache_dir.directory_for(sources)
      end

      cache_dir.cleanup

      units = llvm_modules.map do |type_name, llvm_mod|
        CompilationUnit.new(self, type_name, llvm_mod, output_dir, bc_flags_md5)
      end

      if @cross_compile_flags
        cross_compile program, units, lib_flags, output_filename
      else
        codegen program, units, lib_flags, output_filename, output_dir
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

    private def codegen(program, units : Array(CompilationUnit), lib_flags, output_filename, output_dir)
      object_names = units.map &.object_filename
      target_triple = target_machine.triple

      timing("Codegen (bc+obj)") do
        if units.size == 1
          first_unit = units.first

          codegen_single_unit(program, first_unit, target_triple)

          if emit = @emit
            first_unit.emit(emit, original_output_filename || output_filename)
          end
        else
          codegen_many_units(program, units, target_triple)
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

    private def codegen_many_units(program, units, target_triple)
      jobs_count = 0
      wait_channel = Channel(Nil).new(@n_concurrent)

      while unit = units.pop?
        spawn_and_codegen_single_unit(program, unit, target_triple, wait_channel)
        jobs_count += 1

        if jobs_count >= @n_concurrent
          wait_channel.receive
          jobs_count -= 1
        end
      end

      while jobs_count > 0
        wait_channel.receive
        jobs_count -= 1
      end
    end

    private def spawn_and_codegen_single_unit(program, unit, target_triple, wait_channel)
      spawn do
        codegen_single_unit(program, unit, target_triple)
        wait_channel.send nil
      end
    end

    private def codegen_single_unit(program, unit, target_triple)
      unit.llvm_mod.target = target_triple
      if program.has_flag?("x86_64")
        unit.llvm_mod.data_layout = DataLayout64
      else
        unit.llvm_mod.data_layout = DataLayout32
      end

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

      def initialize(@compiler, type_name, @llvm_mod, @output_dir, bc_flags_md5)
        type_name = "_main" if type_name == ""
        @name = type_name.gsub do |char|
          case char
          when 'a'..'z', 'A'..'Z', '0'..'9', '_'
            char
          else
            char.ord
          end
        end
        @name += bc_flags_md5

        if @name.size > 50
          # 17 chars from name + 1 (dash) + 32 (md5) = 50
          @name = "#{@name[0..16]}-#{Crypto::MD5.hex_digest(@name)}"
        end
      end

      def buffer_to_slice(buf : LibLLVM::MemoryBufferRef)
        ptr = LibLLVM.get_buffer_start(buf)
        size = LibLLVM.get_buffer_size(buf)
        ret = Slice.new ptr, size
        ret
      end

      def compare_slice_to_file(buffer, filename)
        return false if File.size(filename) != buffer.size

        File.open(filename, "rb") do |file|
          read_buf = uninitialized UInt8[8192]
          read_buf_ptr = read_buf.to_unsafe
          walk_ptr = buffer.to_unsafe
          stop_ptr = buffer.to_unsafe + buffer.size

          while true
            return true if walk_ptr == stop_ptr
            gotten_bytes = file.read read_buf.to_slice
            return false if read_buf_ptr.memcmp(walk_ptr, gotten_bytes) != 0
            walk_ptr += gotten_bytes
          end
        end

        return false
      end

      def tempify_name(filename)
        # Just some reasonable insurance it won't clash with a real filename
        filename + "__TMP__.tmp"
      end

      def via_temp_file(filename, &block)
        tmp_name = tempify_name filename
        yield tmp_name
        File.rename tmp_name, filename
      end

      def write_buf_to_file(buffer, filename)
        via_temp_file(filename) do |tmp_name|
          # Do _not_ use File.write - uses to_s => wrecks comparison
          File.open(tmp_name, "w") { |file| file.write buffer }
        end
      end

      def compile
        can_skip_compile = compiler.emit ? false : true
        # Do this before mem–allocation to keep mem total down (many concurrent,
        # and file–ops are rescheduling)
        can_skip_compile &&= File.exists?(object_name)
        can_skip_compile &&= File.exists?(bc_name)

        bc_buf_ref = LibLLVM.write_bitcode_to_memory_buffer(llvm_mod)
        bc_buf = buffer_to_slice bc_buf_ref
        can_skip_compile &&= compare_slice_to_file bc_buf, bc_name

        if can_skip_compile
          LibLLVM.dispose_memory_buffer bc_buf_ref
        else
          write_buf_to_file bc_buf, bc_name
          LibLLVM.dispose_memory_buffer bc_buf_ref

          compiler.optimize llvm_mod if compiler.release?

          via_temp_file(object_name) do |tmp_name|
            compiler.target_machine.emit_obj_to_file llvm_mod, tmp_name
          end
        end

        if compiler.dump_ll?
          via_temp_file(ll_name) do |tmp_name|
            llvm_mod.print_to_file tmp_name
          end
        end
        nil
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

      def ll_name
        "#{@output_dir}/#{@name}.ll"
      end
    end
  end
end
