require "parser"
require "type_inference"
require "visitor"
require "llvm"
require "codegen/*"
require "program"

LLVM.init_x86

module Crystal
  DUMP_LLVM = ENV["DUMP"] == "1"
  VERIFY_LLVM = ENV["VERIFY"] == "1"

  MAIN_NAME = "__crystal_main"
  RAISE_NAME = "__crystal_raise"
  MALLOC_NAME = "__crystal_malloc"
  REALLOC_NAME = "__crystal_realloc"

  class Program
    struct BuildOptions
      property single_module
      property debug
      property llvm_mod
      property use_host_flags

      def initialize
        @single_module = false
        @debug = false
        @llvm_mod = LLVM::Module.new("main_module")
        @use_host_flags = false
      end

      def self.single_module
        options = BuildOptions.new
        options.single_module = true
        options
      end
    end

    def run(code)
      node = Parser.parse(code)
      node = normalize node
      node = infer_type node
      load_libs
      evaluate node
    end

    def evaluate(node)
      llvm_mod = build(node, BuildOptions.single_module)[""]
      llvm_mod.verify
      engine = LLVM::JITCompiler.new(llvm_mod)

      argc = LibLLVM.create_generic_value_of_int(LLVM::Int32, 0_u64, 1)
      argv = LibLLVM.create_generic_value_of_pointer(nil)

      engine.run_function llvm_mod.functions[MAIN_NAME], [argc, argv]
    end

    def build(node, build_options)
      visitor = CodeGenVisitor.new(self, node, build_options)
      begin
        node.accept visitor
        visitor.finish
      rescue ex
        visitor.llvm_mod.dump
        raise ex
      end

      visitor.modules
    end
  end

  class CodeGenVisitor < Visitor
    PERSONALITY_NAME = "__crystal_personality"
    GET_EXCEPTION_NAME = "__crystal_get_exception"

    include LLVMBuilderHelper

    getter :llvm_mod
    getter :fun
    getter :builder
    getter :typer
    getter :main
    getter :modules
    getter :context
    getter :llvm_typer
    property :last

    class LLVMVar
      getter pointer
      getter type

      # Normally a variable is associated with an alloca.
      # So for example, if you have a "x = Reference.new" you will have
      # an "Reference**" llvm value and you need to load that value
      # to access it.
      # However, the "self" argument is not copied to a local variable:
      # it's accessed from the arguments list, and it a "Reference*"
      # llvm value, so in a way it's "already loaded".
      # This field is true if that's the case.
      getter already_loaded

      def initialize(@pointer, @type, @already_loaded = false)
      end
    end

    make_named_tuple Handler, node, catch_block, vars
    make_named_tuple StringKey, mod, string

    def initialize(@mod, @node, build_options = BuildOptions.new)
      @llvm_mod = build_options.llvm_mod
      @single_module = build_options.single_module
      @use_host_flags = build_options.use_host_flags
      @debug = build_options.debug

      @main_mod = @llvm_mod
      @llvm_typer = LLVMTyper.new
      @llvm_id = LLVMId.new(@mod)
      @main_ret_type = node.type
      ret_type = llvm_type(node.type)
      @main = @llvm_mod.functions.add(MAIN_NAME, [LLVM::Int32, pointer_type(pointer_type(LLVM::Int8))], ret_type)

      @context = Context.new @main, @mod

      @argc = @main.get_param(0)
      LLVM.set_name @argc, "argc"

      @argv = @main.get_param(1)
      LLVM.set_name @argv, "argv"

      builder = LLVM::Builder.new
      @builder = CrystalLLVMBuilder.new builder, self

      @dbg_kind = LibLLVM.get_md_kind_id("dbg", 3_u32)

      @modules = {"" => @main_mod} of String => LLVM::Module
      @types_to_modules = {} of Type => LLVM::Module

      @alloca_block, @const_block, @entry_block = new_entry_block_chain({"alloca", "const", "entry"})
      @main_alloca_block = @alloca_block

      @const_block_entry = @const_block
      @lib_vars = {} of String => LibLLVM::ValueRef
      @strings = {} of StringKey => LibLLVM::ValueRef
      @symbols = {} of String => Int32
      @symbol_table_values = [] of LibLLVM::ValueRef
      mod.symbols.each_with_index do |sym, index|
        @symbols[sym] = index
        @symbol_table_values << build_string_constant(sym, sym)
      end

      symbol_table = define_symbol_table @llvm_mod
      LLVM.set_initializer symbol_table, LLVM.array(llvm_type(@mod.string), @symbol_table_values)

      @last = llvm_nil
      @fun_literal_count = 0

      context.return_type = @main_ret_type

      @empty_md_list = metadata([0])
      @subprograms = {} of LLVM::Module => Array(LibLLVM::ValueRef?)
      @subprograms[@main_mod] = [fun_metadata(context.fun, MAIN_NAME, "foo.cr", 1)] if @debug

      alloca_vars @mod.vars, @mod
    end

    def define_symbol_table(llvm_mod)
      llvm_mod.globals.add(LLVM.array_type(llvm_type(@mod.string), @symbol_table_values.count), "symbol_table")
    end

    def type
      context.type.not_nil!
    end

    def finish
      codegen_return @main_ret_type

      br_block_chain [@alloca_block, @const_block_entry]
      br_block_chain [@const_block, @entry_block]

      @modules.each do |name, mod|
        mod.dump if Crystal::DUMP_LLVM
        mod.verify if Crystal::VERIFY_LLVM

        if @debug
          add_compile_unit_metadata(mod, name == "" ? "main" : name)
        end
      end
    end

    def visit(node : FunDef)
      unless node.external.dead
        codegen_fun node.real_name, node.external, @mod, true
      end

      false
    end

    # Can only happen in a Const or as an argument cast,
    # or for primitives where we want a body, like Struct#hash and Struct#==
    def visit(node : Primitive)
      @last = case node.name
              when :argc
                @argc
              when :argv
                @argv
              when :float32_infinity
                LLVM.float(Float32::INFINITY)
              when :float64_infinity
                LLVM.double(Float64::INFINITY)
              when :nil_pointer
                LLVM.null(llvm_type(node.type))
              when :struct_hash
                codegen_primitive_struct_hash
              when :struct_equals
                codegen_primitive_struct_equals
              when :struct_to_s
                codegen_primitive_struct_to_s
              else
                raise "Bug: unhandled primitive in codegen visit: #{node.name}"
              end
    end

    def codegen_primitive(node, target_def, call_args)
      @last = case node.name
              when :binary
                codegen_primitive_binary node, target_def, call_args
              when :cast
                codegen_primitive_cast node, target_def, call_args
              when :allocate
                codegen_primitive_allocate node, target_def, call_args
              when :pointer_malloc
                codegen_primitive_pointer_malloc node, target_def, call_args
              when :pointer_set
                codegen_primitive_pointer_set node, target_def, call_args
              when :pointer_get
                codegen_primitive_pointer_get node, target_def, call_args
              when :pointer_address
                codegen_primitive_pointer_address node, target_def, call_args
              when :pointer_new
                codegen_primitive_pointer_new node, target_def, call_args
              when :pointer_realloc
                codegen_primitive_pointer_realloc node, target_def, call_args
              when :pointer_add
                codegen_primitive_pointer_add node, target_def, call_args
              when :struct_new
                codegen_primitive_struct_new node, target_def, call_args
              when :struct_set
                codegen_primitive_struct_set node, target_def, call_args
              when :struct_get
                codegen_primitive_struct_get node, target_def, call_args
              when :union_new
                codegen_primitive_union_new node, target_def, call_args
              when :union_set
                codegen_primitive_union_set node, target_def, call_args
              when :union_get
                codegen_primitive_union_get node, target_def, call_args
              when :external_var_set
                codegen_primitive_external_var_set node, target_def, call_args
              when :external_var_get
                codegen_primitive_external_var_get node, target_def, call_args
              when :object_id
                codegen_primitive_object_id node, target_def, call_args
              when :object_to_cstr
                codegen_primitive_object_to_cstr node, target_def, call_args
              when :object_crystal_type_id
                codegen_primitive_object_crystal_type_id node, target_def, call_args
              when :math_sqrt_float32
                codegen_primitive_math_sqrt_float32 node, target_def, call_args
              when :math_sqrt_float64
                codegen_primitive_math_sqrt_float64 node, target_def, call_args
              when :float32_pow
                codegen_primitive_float32_pow node, target_def, call_args
              when :float64_pow
                codegen_primitive_float64_pow node, target_def, call_args
              when :symbol_hash
                codegen_primitive_symbol_hash node, target_def, call_args
              when :symbol_to_s
                codegen_primitive_symbol_to_s node, target_def, call_args
              when :class
                codegen_primitive_class node, target_def, call_args
              when :fun_call
                codegen_primitive_fun_call node, target_def, call_args
              when :pointer_diff
                codegen_primitive_pointer_diff node, target_def, call_args
              when :pointer_null
                codegen_primitive_pointer_null node, target_def, call_args
              when :tuple_length
                codegen_primitive_tuple_length node, target_def, call_args
              when :tuple_indexer_known_index
                codegen_primitive_tuple_indexer_known_index node, target_def, call_args
              when :tuple_indexer
                codegen_primitive_tuple_indexer node, target_def, call_args
              else
                raise "Bug: unhandled primitive in codegen: #{node.name}"
              end
    end

    def codegen_primitive_binary(node, target_def, call_args)
      p1, p2 = call_args
      t1, t2 = target_def.owner, target_def.args[0].type
      codegen_binary_op target_def.name, t1, t2, p1, p2
    end

    def codegen_binary_op(op, t1 : BoolType, t2 : BoolType, p1, p2)
      case op
      when "==" then @builder.icmp LibLLVM::IntPredicate::EQ, p1, p2
      when "!=" then @builder.icmp LibLLVM::IntPredicate::NE, p1, p2
      else raise "Bug: trying to codegen #{t1} #{op} #{t2}"
      end
    end

    def codegen_binary_op(op, t1 : CharType, t2 : CharType, p1, p2)
      case op
      when "==" then return @builder.icmp LibLLVM::IntPredicate::EQ, p1, p2
      when "!=" then return @builder.icmp LibLLVM::IntPredicate::NE, p1, p2
      when "<" then return @builder.icmp LibLLVM::IntPredicate::ULT, p1, p2
      when "<=" then return @builder.icmp LibLLVM::IntPredicate::ULE, p1, p2
      when ">" then return @builder.icmp LibLLVM::IntPredicate::UGT, p1, p2
      when ">=" then return @builder.icmp LibLLVM::IntPredicate::UGE, p1, p2
      else raise "Bug: trying to codegen #{t1} #{op} #{t2}"
      end
    end

    def codegen_binary_op(op, t1 : SymbolType, t2 : SymbolType, p1, p2)
      case op
      when "==" then return @builder.icmp LibLLVM::IntPredicate::EQ, p1, p2
      when "!=" then return @builder.icmp LibLLVM::IntPredicate::NE, p1, p2
      else raise "Bug: trying to codegen #{t1} #{op} #{t2}"
      end
    end

    def codegen_binary_op(op, t1 : IntegerType, t2 : IntegerType, p1, p2)
      if t1.normal_rank == t2.normal_rank
        # Nothing to do
      elsif t1.rank < t2.rank
        p1 = extend_int t1, t2, p1
      else
        p2 = extend_int t2, t1, p2
      end

      @last = case op
              when "+" then @builder.add p1, p2
              when "-" then @builder.sub p1, p2
              when "*" then @builder.mul p1, p2
              when "/" then t1.signed? ? @builder.sdiv(p1, p2) : @builder.udiv(p1, p2)
              when "%" then t1.signed? ? @builder.srem(p1, p2) : @builder.urem(p1, p2)
              when "<<" then @builder.shl(p1, p2)
              when ">>" then t1.signed? ? @builder.ashr(p1, p2) : @builder.lshr(p1, p2)
              when "|" then or(p1, p2)
              when "&" then and(p1, p2)
              when "^" then @builder.xor(p1, p2)
              when "==" then return @builder.icmp LibLLVM::IntPredicate::EQ, p1, p2
              when "!=" then return @builder.icmp LibLLVM::IntPredicate::NE, p1, p2
              when "<" then return @builder.icmp (t1.signed? ? LibLLVM::IntPredicate::SLT : LibLLVM::IntPredicate::ULT), p1, p2
              when "<=" then return @builder.icmp (t1.signed? ? LibLLVM::IntPredicate::SLE : LibLLVM::IntPredicate::ULE), p1, p2
              when ">" then return @builder.icmp (t1.signed? ? LibLLVM::IntPredicate::SGT : LibLLVM::IntPredicate::UGT), p1, p2
              when ">=" then return @builder.icmp (t1.signed? ? LibLLVM::IntPredicate::SGE : LibLLVM::IntPredicate::UGE), p1, p2
              else raise "Bug: trying to codegen #{t1} #{op} #{t2}"
              end

      if t1.normal_rank != t2.normal_rank  && t1.rank < t2.rank
        @last = trunc @last, llvm_type(t1)
      end

      @last
    end

    def codegen_binary_op(op, t1 : IntegerType, t2 : FloatType, p1, p2)
      p1 = codegen_cast(t1, t2, p1)
      codegen_binary_op(op, t2, t2, p1, p2)
    end

    def codegen_binary_op(op, t1 : FloatType, t2 : IntegerType, p1, p2)
      p2 = codegen_cast(t2, t1, p2)
      codegen_binary_op op, t1, t1, p1, p2
    end

    def codegen_binary_op(op, t1 : FloatType, t2 : FloatType, p1, p2)
      if t1.rank < t2.rank
        p1 = extend_float t2, p1
      elsif t1.rank > t2.rank
        p2 = extend_float t1, p2
      end

      @last = case op
              when "+" then @builder.fadd p1, p2
              when "-" then @builder.fsub p1, p2
              when "*" then @builder.fmul p1, p2
              when "/" then @builder.fdiv p1, p2
              when "==" then return @builder.fcmp LibLLVM::RealPredicate::OEQ, p1, p2
              when "!=" then return @builder.fcmp LibLLVM::RealPredicate::ONE, p1, p2
              when "<" then return @builder.fcmp LibLLVM::RealPredicate::OLT, p1, p2
              when "<=" then return @builder.fcmp LibLLVM::RealPredicate::OLE, p1, p2
              when ">" then return @builder.fcmp LibLLVM::RealPredicate::OGT, p1, p2
              when ">=" then return @builder.fcmp LibLLVM::RealPredicate::OGE, p1, p2
              else raise "Bug: trying to codegen #{t1} #{op} #{t2}"
              end
      @last = trunc_float t1, @last if t1.rank < t2.rank
      @last
    end

    def codegen_binary_op(op, t1, t2, p1, p2)
      raise "Bug: codegen_binary_op called with #{t1} #{op} #{t2}"
    end

    def codegen_primitive_cast(node, target_def, call_args)
      p1 = call_args[0]
      from_type, to_type = target_def.owner, target_def.type
      codegen_cast from_type, to_type, p1
    end

    def codegen_cast(from_type : IntegerType, to_type : IntegerType, arg)
      if from_type.normal_rank == to_type.normal_rank
        arg
      elsif from_type.rank < to_type.rank
        extend_int from_type, to_type, arg
      else
        trunc arg, llvm_type(to_type)
      end
    end

    def codegen_cast(from_type : IntegerType, to_type : FloatType, arg)
      int_to_float from_type, to_type, arg
    end

    def codegen_cast(from_type : FloatType, to_type : IntegerType, arg)
      float_to_int from_type, to_type, arg
    end

    def codegen_cast(from_type : FloatType, to_type : FloatType, arg)
      if from_type.rank < to_type.rank
        extend_float to_type, arg
      elsif from_type.rank > to_type.rank
        trunc_float to_type, arg
      else
        arg
      end
    end

    def codegen_cast(from_type : IntegerType, to_type : CharType, arg)
      codegen_cast from_type, @mod.int32, arg
    end

    def codegen_cast(from_type : CharType, to_type : IntegerType, arg)
      @builder.zext arg, llvm_type(to_type)
    end

    def codegen_cast(from_type : SymbolType, to_type : IntegerType, arg)
      arg
    end

    def codegen_cast(from_type, to_type, arg)
      raise "Bug: codegen_cast called from #{from_type} to #{to_type}"
    end

    def codegen_primitive_allocate(node, target_def, call_args)
      type = node.type
      base_type = type.is_a?(HierarchyType) ? type.base_type : type

      allocate_aggregate base_type

      unless type.struct?
        type_id_ptr = aggregate_index(@last, 0)
        store type_id(base_type), type_id_ptr
      end

      if type.is_a?(HierarchyType)
        @last = cast_to @last, type
      end

      @last
    end

    def codegen_primitive_pointer_malloc(node, target_def, call_args)
      type = node.type as PointerInstanceType
      llvm_type = llvm_embedded_type(type.element_type)
      array_malloc(llvm_type, call_args[1])
    end

    def codegen_primitive_pointer_set(node, target_def, call_args)
      type = context.type as PointerInstanceType
      value = call_args[1]
      assign call_args[0], type.element_type, node.type, value
      value
    end

    def codegen_primitive_pointer_get(node, target_def, call_args)
      type = context.type as PointerInstanceType
      to_lhs call_args[0], type.element_type
    end

    def codegen_primitive_pointer_address(node, target_def, call_args)
      ptr2int call_args[0], LLVM::Int64
    end

    def codegen_primitive_pointer_new(node, target_def, call_args)
      int2ptr(call_args[1], llvm_type(node.type))
    end

    def codegen_primitive_pointer_realloc(node, target_def, call_args)
      type = context.type as PointerInstanceType

      casted_ptr = cast_to_void_pointer(call_args[0])
      size = @builder.mul call_args[1], llvm_size(type.element_type)
      reallocated_ptr = realloc casted_ptr, size
      cast_to_pointer reallocated_ptr, type.element_type
    end

    def codegen_primitive_pointer_add(node, target_def, call_args)
      gep call_args[0], call_args[1]
    end

    def codegen_primitive_struct_new(node, target_def, call_args)
      allocate_aggregate (node.type as PointerInstanceType).element_type
    end

    def codegen_primitive_struct_set(node, target_def, call_args)
      set_aggregate_field(node, target_def, call_args) do
        type = context.type as CStructType
        name = target_def.name[0 .. -2]
        struct_field_ptr(type, name, call_args[0])
      end
    end

    def codegen_primitive_struct_get(node, target_def, call_args)
      type = context.type as CStructType
      to_lhs struct_field_ptr(type, target_def.name, call_args[0]), node.type
    end

    def struct_field_ptr(type, field_name, pointer)
      index = type.index_of_var(field_name)
      aggregate_index pointer, index
    end

    def codegen_primitive_union_new(node, target_def, call_args)
      allocate_aggregate (node.type as PointerInstanceType).element_type
    end

    def codegen_primitive_union_set(node, target_def, call_args)
      set_aggregate_field(node, target_def, call_args) do
        union_field_ptr(node, call_args[0])
      end
    end

    def codegen_primitive_union_get(node, target_def, call_args)
      to_lhs union_field_ptr(node, call_args[0]), node.type
    end

    def set_aggregate_field(node, target_def, call_args)
      value = to_rhs call_args[1], node.type
      store value, yield
      call_args[1]
    end

    def union_field_ptr(node, pointer)
      ptr = aggregate_index pointer, 0
      cast_to_pointer ptr, node.type
    end

    def codegen_primitive_external_var_set(node, target_def, call_args)
      external = target_def as External
      name = external.real_name
      var = declare_lib_var name, node.type, external.attributes
      @last = call_args[0]
      store @last, var
      @last
    end

    def codegen_primitive_external_var_get(node, target_def, call_args)
      external = target_def as External
      name = (target_def as External).real_name
      var = declare_lib_var name, node.type, external.attributes
      load var
    end

    def codegen_primitive_object_id(node, target_def, call_args)
      ptr2int call_args[0], LLVM::Int64
    end

    def codegen_primitive_object_to_cstr(node, target_def, call_args)
      type = context.type
      case type
      when MetaclassType
        type_to_s = type.instance_type.to_s
        want_object_id = false
      when GenericClassInstanceMetaclassType
        type_to_s = type.instance_type.to_s
        want_object_id = false
      else
        type_to_s = type.to_s
        want_object_id = true
      end

      if want_object_id
        buffer = array_malloc(LLVM::Int8, int(type_to_s.length + 23))
        call @mod.sprintf(@llvm_mod), [buffer, @builder.global_string_pointer("<#{type_to_s}:0x%016lx>"), call_args[0]] of LibLLVM::ValueRef
        buffer
      else
        @builder.global_string_pointer(type_to_s)
      end
    end

    def codegen_primitive_object_crystal_type_id(node, target_def, call_args)
      type_id(type)
    end

    def codegen_primitive_math_sqrt_float32(node, target_def, call_args)
      call @mod.sqrt_float32(@llvm_mod), [call_args[1]]
    end

    def codegen_primitive_math_sqrt_float64(node, target_def, call_args)
      call @mod.sqrt_float64(@llvm_mod), [call_args[1]]
    end

    def codegen_primitive_float32_pow(node, target_def, call_args)
      call @mod.pow_float32(@llvm_mod), call_args
    end

    def codegen_primitive_float64_pow(node, target_def, call_args)
      call @mod.pow_float64(@llvm_mod), call_args
    end

    def codegen_primitive_symbol_to_s(node, target_def, call_args)
      load(gep @llvm_mod.globals["symbol_table"], int(0), call_args[0])
    end

    def codegen_primitive_symbol_hash(node, target_def, call_args)
      call_args[0]
    end

    def codegen_primitive_class(node, target_def, call_args)
      if node.type.hierarchy_metaclass?
        load aggregate_index(call_args[0], 0)
      else
        type_id(node.type)
      end
    end

    def codegen_primitive_fun_call(node, target_def, call_args)
      codegen_call_or_invoke(node, call_args[0], call_args[1 .. -1], true, target_def.type)
    end

    def codegen_primitive_pointer_diff(node, target_def, call_args)
      p0 = ptr2int(call_args[0], LLVM::Int64)
      p1 = ptr2int(call_args[1], LLVM::Int64)
      sub = @builder.sub p0, p1
      @builder.exact_sdiv sub, ptr2int(gep(LLVM.pointer_null(type_of(call_args[0])), 1), LLVM::Int64)
    end

    def codegen_primitive_pointer_null(node, target_def, call_args)
      LLVM.null(llvm_type(node.type))
    end

    def codegen_primitive_tuple_length(node, target_def, call_args)
      type = context.type as TupleInstanceType
      int(type.tuple_types.length)
    end

    def codegen_primitive_tuple_indexer_known_index(node, target_def, call_args)
      type = context.type as TupleInstanceType
      index = (node as TupleIndexer).index
      ptr = aggregate_index call_args[0], index
      to_lhs ptr, type.tuple_types[index]
    end

    def codegen_primitive_tuple_indexer(node, target_def, call_args)
      type = context.type as TupleInstanceType
      tuple = call_args[0]
      index = call_args[1]
      Phi.open(self, node) do |phi|
        type.tuple_types.each_with_index do |tuple_type, i|
          current_index_label, next_index_label = new_blocks({"current_index", "next_index"})
          cond equal?(index, int(i)), current_index_label, next_index_label

          position_at_end current_index_label

          ptr = aggregate_index tuple, i
          value = to_lhs(ptr, tuple_type)
          phi.add value, tuple_type

          position_at_end next_index_label
        end
        accept index_out_of_bounds_exception_call
      end
    end

    def codegen_primitive_struct_hash
      type = context.type as InstanceVarContainer
      ivars = type.all_instance_vars

      # Generate:
      # hash = 0
      # - for each instance var
      #   hash = 31 * hash + @ivar.hash
      # - end
      # hash

      hash_var = Var.new("hash")
      n0 = NumberLiteral.new(0, :i32)
      n31 = NumberLiteral.new(31, :i32)

      vars = MetaVars.new
      vars["hash"] = MetaVar.new(hash_var.name)

      exps = [] of ASTNode
      exps << Assign.new(hash_var, n0)
      i = 0
      ivars.each_value do |ivar|
        ivar_name = "#ivar#{i}"
        ivar_var = Var.new(ivar_name, ivar.type)

        context.vars[ivar_name] = LLVMVar.new(aggregate_index(llvm_self, i), ivar.type)
        vars[ivar_name] = MetaVar.new(ivar_var.name)

        mul = Call.new(n31, "*", [hash_var] of ASTNode)
        ivar_hash = Call.new(ivar_var, "hash")
        add = Call.new(mul, "+", [ivar_hash] of ASTNode)
        exps << Assign.new(hash_var, add)
        i += 1
      end
      exps << hash_var
      exps = Expressions.new(exps)
      visitor = TypeVisitor.new(@mod, vars, Def.new("dummy", [] of Arg))
      exps.accept visitor
      alloca_vars visitor.meta_vars
      exps.accept self
      @last
    end

    def codegen_primitive_struct_equals
      type = context.type as InstanceVarContainer
      ivars = type.all_instance_vars

      other = context.vars["other"].pointer

      # Generate:
      # - for each instance var
      #   return false if self.ivar != other.ivar
      # - end
      # true
      # hash

      vars = MetaVars.new

      exps = [] of ASTNode

      i = 0
      ivars.each_value do |ivar|
        self_ivar_name = "#my_ivar#{i}"
        other_ivar_name = "#other_ivar#{i}"

        self_ivar = Var.new(self_ivar_name, ivar.type)
        other_ivar = Var.new(other_ivar_name, ivar.type)

        context.vars[self_ivar_name] = LLVMVar.new(aggregate_index(llvm_self, i), ivar.type)
        context.vars[other_ivar_name] = LLVMVar.new(aggregate_index(other, i), ivar.type)

        vars[self_ivar_name] = MetaVar.new(self_ivar.name)
        vars[other_ivar_name] = MetaVar.new(other_ivar.name)

        cmp = Call.new(self_ivar, "!=", [other_ivar] of ASTNode)
        exps << If.new(cmp, Return.new([BoolLiteral.new(false)] of ASTNode))

        i += 1
      end

      exps << BoolLiteral.new(true)
      exps = Expressions.from(exps)
      exps.accept TypeVisitor.new(@mod, vars, Def.new("dummy", [] of Arg))
      exps.accept self
      @last
    end

    def codegen_primitive_struct_to_s
      type = context.type as InstanceVarContainer
      ivars = type.all_instance_vars

      # Generate
      # "ClassName(#{ivar_name}=#{ivar_value}, ...)"

      vars = MetaVars.new

      exps = [] of ASTNode
      exps << StringLiteral.new("#{type}(")
      i = 0
      ivars.each_value do |ivar|
        ivar_name = "#ivar#{i}"
        ivar_var = Var.new(ivar_name, ivar.type)

        context.vars[ivar_name] = LLVMVar.new(aggregate_index(llvm_self, i), ivar.type)
        vars[ivar_name] = MetaVar.new(ivar_var.name)

        exps << StringLiteral.new(i == 0 ? "#{ivar.name}=" : ", #{ivar.name}=")
        exps << ivar_var
        i += 1
      end
      exps << StringLiteral.new(")")
      exps = StringInterpolation.new(exps)
      exps = @mod.normalize(exps)
      exps.accept TypeVisitor.new(@mod, vars, Def.new("dummy", [] of Arg))
      exps.accept self
      @last
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : Nop)
      @last = llvm_nil
    end

    def visit(node : NilLiteral)
      @last = llvm_nil
    end

    def visit(node : BoolLiteral)
      @last = int1(node.value ? 1 : 0)
    end

    def visit(node : CharLiteral)
      @last = int32(node.value.ord)
    end

    def visit(node : NumberLiteral)
      case node.kind
      when :i8, :u8
        @last = int8(node.value.to_i)
      when :i16, :u16
        @last = int16(node.value.to_i)
      when :i32, :u32
        @last = int32(node.value.to_i)
      when :i64, :u64
        @last = int64(node.value.to_i64)
      when :f32
        @last = LLVM.float(node.value)
      when :f64
        @last = LLVM.double(node.value)
      end
    end

    def visit(node : StringLiteral)
      @last = build_string_constant(node.value)
    end

    def visit(node : SymbolLiteral)
      @last = int(@symbols[node.value])
    end

    def visit(node : TupleLiteral)
      type = node.type as TupleInstanceType
      @last = allocate_tuple(type) do |tuple_type, i|
        exp = node.exps[i]
        exp.accept self
        {exp.type, @last}
      end
      false
    end

    def visit(node : PointerOf)
      @last = case node_exp = node.exp
              when Var
                context.vars[node_exp.name].pointer
              when InstanceVar
                instance_var_ptr (context.type as InstanceVarContainer), node_exp.name, llvm_self_ptr
              when IndirectRead
                visit_indirect(node_exp)
              else
                raise "Bug: pointerof(#{node})"
              end
      false
    end

    def visit(node : SimpleOr)
      @last = or codegen_cond(node.left), codegen_cond(node.right)
      false
    end

    def visit(node : FunLiteral)
      @fun_literal_count += 1

      fun_literal_name = "~fun_literal_#{@fun_literal_count}"
      is_closure = !!context.closure_vars
      the_fun = codegen_fun(fun_literal_name, node.def, @mod, false, @main_mod, is_closure)
      @last = (check_main_fun fun_literal_name, the_fun).fun

      if is_closure
        trampoline_init node.type, @last, context.closure_ptr.not_nil!
      end

      false
    end

    def visit(node : FunPointer)
      owner = node.call.target_def.owner.not_nil!
      if obj = node.obj
        accept obj
        call_self = @last
      elsif owner.passed_as_self?
        call_self = llvm_self
      end
      last_fun = target_def_fun(node.call.target_def, owner)
      @last = last_fun.fun

      if call_self
        wrapper = trampoline_wrapper(node.call.target_def, last_fun)
        trampoline_init node.type, wrapper.fun, call_self
      end

      false
    end

    def trampoline_wrapper(target_def, target_fun)
      key = target_def.object_id
      wrappers = (@trampoline_wrappers ||= {} of UInt64 => LLVM::Function)
      wrappers[key] ||= begin
        param_types = target_fun.param_types
        ret_type = target_fun.return_type
        @llvm_mod.functions.add("trampoline_wrapper_#{key}", param_types, ret_type) do |func|
          func.linkage = LibLLVM::Linkage::Internal if @single_module
          LLVM.add_attribute func.get_param(0), LibLLVM::Attribute::Nest
          func.append_basic_block("entry") do |builder|
            call_ret = builder.call target_fun, func.params
            case target_def.type
            when .no_return?
              builder.unreachable
            when .void?
              builder.ret
            else
              builder.ret call_ret
            end
          end
        end
      end
    end

    def trampoline_init(type, wrapper, nest)
      tramp_ptr = array_malloc(LLVM::Int8, int(32))
      call @mod.trampoline_init(@llvm_mod), [
        tramp_ptr,
        bit_cast(wrapper, pointer_type(LLVM::Int8)),
        bit_cast(nest, pointer_type(LLVM::Int8))
      ]
      @last = call @mod.trampoline_adjust(@llvm_mod), [tramp_ptr]
      @last = cast_to @last, type
    end

    def visit(node : Expressions)
      node.expressions.each do |exp|
        accept exp
        break if exp.no_returns? || exp.returns? || exp.breaks? || (exp.yields? && (block_returns? || block_breaks?))
      end
      false
    end

    def visit(node : Return)
      node_type = accept_control_expression(node)

      if handler = @exception_handlers.try &.last?
        if node_ensure = handler.node.ensure
          old_last = @last
          with_cloned_context do
            context.vars = handler.vars
            accept node_ensure
          end
          @last = old_last
        end
      end

      if return_phi = context.return_phi
        return_phi.add @last, node_type
      else
        codegen_return node_type
      end

      false
    end

    def codegen_return(type : NoReturnType | Nil)
      unreachable
    end

    def codegen_return(type : Type)
      method_type = context.return_type.not_nil!
      if method_type.void?
        ret
      else
        value = upcast(@last, method_type, type)
        ret to_rhs(value, method_type)
      end
    end

    def visit(node : ClassDef)
      accept node.body
      @last = llvm_nil
      false
    end

    def visit(node : ModuleDef)
      accept node.body
      @last = llvm_nil
      false
    end

    def visit(node : LibDef)
      @last = llvm_nil
      false
    end

    def visit(node : Alias)
      @last = llvm_nil
      false
    end

    def visit(node : TypeOf)
      @last = type_id(node.type)
      false
    end

    def visit(node : SizeOf)
      @last = trunc(llvm_size(node.exp.type.instance_type), LLVM::Int32)
      false
    end

    def visit(node : InstanceSizeOf)
      @last = trunc(llvm_struct_size(node.exp.type.instance_type), LLVM::Int32)
      false
    end

    def visit(node : Include)
      @last = llvm_nil
      false
    end

    def visit(node : Extend)
      @last = llvm_nil
      false
    end

    def visit(node : If)
      then_block, else_block = new_blocks({"then", "else"})

      codegen_cond_branch node.cond, then_block, else_block

      Phi.open(self, node) do |phi|
        codegen_if_branch phi, node.then, then_block
        codegen_if_branch phi, node.else, else_block
      end

      false
    end

    def codegen_if_branch(phi, node, branch_block)
      position_at_end branch_block
      accept node
      phi.add @last, node.type?
    end

    def visit(node : While)
      with_cloned_context do
        while_block, body_block, exit_block = new_blocks({"while", "body", "exit"})

        context.while_block = while_block
        context.while_exit_block = exit_block
        context.break_phi = nil
        context.next_phi = nil

        br node.run_once ? body_block : while_block

        position_at_end while_block

        codegen_cond_branch node.cond, body_block, exit_block

        position_at_end body_block
        accept node.body
        br while_block

        position_at_end exit_block

        if node.no_returns? || (node.body.yields? && block_breaks?)
          unreachable
        else
          @last = llvm_nil
        end
      end

      false
    end

    def codegen_cond_branch(node_cond, then_block, else_block)
      cond codegen_cond(node_cond), then_block, else_block

      nil
    end

    def codegen_cond(node : ASTNode)
      accept node
      codegen_cond node.type
    end

    def visit(node : Break)
      node_type = accept_control_expression(node)

      if break_phi = context.break_phi
        break_phi.add @last, node_type
      elsif while_exit_block = context.while_exit_block
        br while_exit_block
      else
        node.raise "Bug: unknown exit for break"
      end

      false
    end

    def visit(node : Next)
      node_type = accept_control_expression(node)

      if next_phi = context.next_phi
        next_phi.add @last, node_type
      elsif while_block = context.while_block
        br while_block
      else
        node.raise "Bug: unknown exit for next"
      end

      false
    end

    def accept_control_expression(node)
      if node.exps.empty?
        @last = llvm_nil
        @mod.nil
      else
        exp = node.exps.first
        accept exp
        exp.type? || @mod.nil
      end
    end

    def visit(node : Assign)
      target, value = node.target, node.value

      if target.is_a?(Path)
        @last = llvm_nil
        return false
      end

      accept value

      if value.no_returns? || value.returns? || value.breaks? || (value.yields? && (block_returns? || block_breaks?))
        return
      end

      target_type = target.type

      ptr = case target
            when InstanceVar
              instance_var_ptr (context.type as InstanceVarContainer), target.name, llvm_self_ptr
            when Global
              get_global target.name, target.type
            when ClassVar
              get_global class_var_global_name(target), target.type
            when Var
              # Can't assign void
              return if target.type.void?

              var = context.vars[target.name]?
              if var
                target_type = var.type
                var.pointer
              else
                target.raise "Bug: missing var #{target}"
              end
            else
              node.raise "Unknown assign target in codegen: #{target}"
            end

      store_instruction = assign ptr, target_type, value.type, @last
      emit_debug_metadata node, store_instruction if @debug

      false
    end

    def get_global(name, type)
      ptr = @llvm_mod.globals[name]?
      unless ptr
        llvm_type = llvm_type(type)

        global_var = @mod.global_vars[name]?
        thread_local = global_var.try &.has_attribute?("ThreadLocal")

        # Declare global in this module as external
        ptr = @llvm_mod.globals.add(llvm_type, name)
        LLVM.set_thread_local ptr, thread_local if thread_local

        if @llvm_mod == @main_mod
          LLVM.set_initializer ptr, LLVM.null(llvm_type)
        else
          LLVM.set_linkage ptr, LibLLVM::Linkage::External

          # Define it in main if it's not already defined
          main_ptr = @main_mod.globals[name]?
          unless main_ptr
            main_ptr = @main_mod.globals.add(llvm_type, name)
            LLVM.set_initializer main_ptr, LLVM.null(llvm_type)
            LLVM.set_thread_local main_ptr, thread_local if thread_local
          end
        end
      end
      ptr
    end

    def class_var_global_name(node)
      "#{node.owner}#{node.var.name.replace('@', ':')}"
    end

    def visit(node : DeclareVar)
      var = node.var
      case var
      when Var
        llvm_var = declare_var var
        @last = llvm_var.pointer
      when InstanceVar
        var.accept self
      end
      false
    end

    def visit(node : Var)
      var = context.vars[node.name]
      @last = downcast var.pointer, node.type, var.type, var.already_loaded
    end

    def visit(node : Global)
      read_global node.name.to_s, node.type
    end

    def visit(node : ClassVar)
      read_global class_var_global_name(node), node.type
    end

    def read_global(name, type)
      @last = get_global name, type
      @last = to_lhs @last, type
    end

    def visit(node : InstanceVar)
      type = context.type as InstanceVarContainer
      ivar = type.lookup_instance_var(node.name)
      ivar_ptr = instance_var_ptr type, node.name, llvm_self_ptr
      @last = downcast ivar_ptr, node.type, ivar.type, false
    end

    def visit(node : Cast)
      accept node.obj
      last_value = @last

      obj_type = node.obj.type
      to_type = node.to.type.instance_type

      if obj_type.pointer? || obj_type.fun?
        @last = cast_to last_value, to_type
      else
        resulting_type = obj_type.filter_by(to_type).not_nil!

        type_id = type_id last_value, obj_type
        cmp = match_type_id obj_type, resulting_type, type_id

        matches_block, doesnt_match_block = new_blocks({"matches", "doesnt_match"})
        cond cmp, matches_block, doesnt_match_block

        position_at_end doesnt_match_block
        accept type_cast_exception_call

        position_at_end matches_block
        @last = downcast last_value, resulting_type, obj_type, true
      end

      false
    end

    def type_cast_exception_call
      @type_cast_exception_call ||= begin
        call = Call.new(nil, "raise", [StringLiteral.new("type cast exception")] of ASTNode, nil, nil, true)
        @mod.infer_type call
        call
      end
    end

    def index_out_of_bounds_exception_call
      @index_out_of_bounds_exception_call ||= begin
        call = Call.new(nil, "raise", [StringLiteral.new("index out of bounds")] of ASTNode, nil, nil, true)
        @mod.infer_type call
        call
      end
    end

    def visit(node : IsA)
      codegen_type_filter node, &.filter_by(node.const.type.instance_type)
    end

    def visit(node : RespondsTo)
      codegen_type_filter node, &.filter_by_responds_to(node.name.value)
    end

    def codegen_type_filter(node)
      accept node.obj
      obj_type = node.obj.type

      type_id = type_id @last, obj_type
      filtered_type = yield(obj_type).not_nil!

      @last = match_type_id obj_type, filtered_type, type_id

      false
    end

    def declare_var(var)
      context.vars[var.name] ||= LLVMVar.new(alloca(llvm_type(var.type), var.name), var.type)
    end

    def declare_lib_var(name, type, attributes)
      unless var = @lib_vars[name]?
        var = @llvm_mod.globals.add(llvm_type(type), name)
        LLVM.set_linkage var, LibLLVM::Linkage::External
        LLVM.set_thread_local var if Attribute.any?(attributes, "ThreadLocal")
        @lib_vars[name] = var
      end
      var
    end

    def visit(node : Def)
      @last = llvm_nil
      false
    end

    def visit(node : Macro)
      @last = llvm_nil
      false
    end

    def visit(node : Path)
      if const = node.target_const
        global_name = const.llvm_name
        global = @main_mod.globals[global_name]?

        unless global
          global = @main_mod.globals.add(llvm_type(const.value.type), global_name)

          if const.value.needs_const_block?
            in_const_block("const_#{global_name}") do
              alloca_vars const.vars
              accept const.not_nil!.value

              if LLVM.constant? @last
                LLVM.set_initializer global, @last
                LLVM.set_global_constant global, true
              else
                if const.value.type.passed_by_value?
                  @last = load @last
                  LLVM.set_initializer global, LLVM.undef(llvm_type(const.value.type))
                else
                  LLVM.set_initializer global, LLVM.null(type_of @last)
                end

                store @last, global
              end
            end
          else
            old_llvm_mod = @llvm_mod
            @llvm_mod = @main_mod
            accept const.value
            LLVM.set_initializer global, @last
            LLVM.set_global_constant global, true
            @llvm_mod = old_llvm_mod
          end
        end

        if @llvm_mod != @main_mod
          global = @llvm_mod.globals[global_name]?
          global ||= @llvm_mod.globals.add(llvm_type(const.value.type), global_name)
        end

        @last = to_lhs global, const.value.type
      elsif replacement = node.syntax_replacement
        accept replacement
      else
        node_type = node.type
        # Special case: if the type is a type tuple we need to create a tuple for it
        if node_type.is_a?(TupleInstanceType)
          @last = allocate_tuple(node_type) do |tuple_type, i|
            {tuple_type, type_id(tuple_type)}
          end
        else
          @last = type_id(node.type)
        end
      end
      false
    end

    def visit(node : Generic)
      @last = type_id(node.type)
      false
    end

    def visit(node : Yield)
      block_context = context.block_context.not_nil!
      new_vars = block_context.vars.dup
      block = context.block

      if node_scope = node.scope
        accept node_scope
        new_vars["%scope"] = LLVMVar.new(@last, node_scope.type)
      end

      # First accept all yield expressions
      node.exps.each_with_index do |exp, i|
        accept exp

        if arg = block.args[i]?
          create_yield_var arg, exp.type, new_vars, @last
        end
      end

      # Then assign nil to remaining block args
      node.exps.length.upto(block.args.length - 1) do |i|
        create_yield_var block.args[i], @mod.nil, new_vars, llvm_nil
      end

      Phi.open(self, block) do |phi|
        with_cloned_context(block_context) do |old|
          context.vars = new_vars

          # Declare block args
          alloca_vars block.before_vars, block

          # And reset those that are declared inside the block and are nilable.
          reset_block_vars block

          context.break_phi = old.return_phi
          context.next_phi = phi
          context.while_exit_block = nil
          accept block
        end

        phi.add @last, block.body.type?
      end

      false
    end

    def create_yield_var(arg, exp_type, vars, value)
      copy = alloca llvm_type(arg.type), "block_#{arg.name}"
      assign copy, arg.type, exp_type, value
      vars[arg.name] = LLVMVar.new(copy, arg.type)
    end

    def visit(node : ExceptionHandler)
      catch_block = new_block "catch"
      node_ensure = node.ensure

      Phi.open(self, node) do |phi|
        exception_handlers = (@exception_handlers ||= [] of Handler)
        exception_handlers << Handler.new(node, catch_block, context.vars)
        accept node.body
        exception_handlers.pop

        if node_else = node.else
          accept node_else
          phi.add @last, node_else.type
        else
          phi.add @last, node.body.type
        end

        position_at_end catch_block
        lp_ret_type = llvm_typer.landing_pad_type
        lp = @builder.landing_pad lp_ret_type, main_fun(PERSONALITY_NAME).fun, [] of LibLLVM::ValueRef
        unwind_ex_obj = @builder.extract_value lp, 0
        ex_type_id = @builder.extract_value lp, 1

        if node_rescues = node.rescues
          node_rescues.each do |a_rescue|
            this_rescue_block, next_rescue_block = new_blocks({"this_rescue", "next_rescue"})
            if a_rescue_types = a_rescue.types
              cond = nil
              a_rescue_types.each do |type|
                rescue_type = type.type.instance_type.hierarchy_type
                rescue_type_cond = match_any_type_id(rescue_type, ex_type_id)
                cond = cond ? or(cond, rescue_type_cond) : rescue_type_cond
              end
              cond cond.not_nil!, this_rescue_block, next_rescue_block
            else
              br this_rescue_block
            end
            position_at_end this_rescue_block

            with_cloned_context do
              if a_rescue_name = a_rescue.name
                context.vars = context.vars.dup
                get_exception_fun = main_fun(GET_EXCEPTION_NAME)
                exception_ptr = call get_exception_fun, [bit_cast(unwind_ex_obj, type_of(get_exception_fun.get_param(0)))]
                exception = int2ptr exception_ptr, LLVMTyper::TYPE_ID_POINTER
                unless a_rescue.type.hierarchy?
                  exception = cast_to exception, a_rescue.type
                end
                context.vars[a_rescue_name] = LLVMVar.new(exception, a_rescue.type, true)
              end

              accept a_rescue.body
            end
            phi.add @last, a_rescue.body.type

            position_at_end next_rescue_block
          end
        end

        if node_ensure
          accept node_ensure
        end

        raise_fun = main_fun(RAISE_NAME)
        codegen_call_or_invoke(node, raise_fun, [bit_cast(unwind_ex_obj, type_of(raise_fun.get_param(0)))], true, @mod.no_return)
      end

      if node_ensure
        old_last = @last
        accept node_ensure
        @last = old_last
      end

      false
    end

    def visit(node : IndirectRead)
      ptr = visit_indirect(node)
      ptr = cast_to_pointer ptr, node.type
      @last = to_lhs ptr, node.type

      false
    end

    def visit(node : IndirectWrite)
      ptr = visit_indirect(node)
      ptr = cast_to_pointer ptr, node.value.type

      accept node.value

      @last = to_rhs @last, node.value.type

      store @last, ptr

      false
    end

    def visit_indirect(node)
      indices = [int32(0)]

      type = node.obj.type as PointerInstanceType

      element_type = type.element_type

      node.names.each do |name|
        case element_type
        when CStructType
          index = element_type.vars.key_index(name).not_nil!
          var = element_type.vars[name]

          indices << int32(index)
          element_type = var.type
        when CUnionType
          var = element_type.vars[name]

          indices << int32(0)
          element_type = var.type
        else
          node.raise "Bug: #{node} had a wrong type (#{element_type})"
        end
      end

      accept node.obj

      @builder.gep @last, indices
    end

    def visit(node : Call)
      if target_macro = node.target_macro
        accept target_macro
        return false
      end

      target_defs = node.target_defs.not_nil!
      if target_defs.length > 1
        codegen_dispatch node, target_defs
        return false
      end

      owner = node.name == "super" ? node.scope : node.target_def.owner.not_nil!

      call_args, has_out = prepare_call_args node, owner

      return if node.args.any?(&.yields?) && block_breaks?

      if block = node.block
        with_cloned_context do |old_context|
          codegen_call_with_block(node, block, owner, call_args, old_context)
        end
      else
        codegen_call(node, node.target_def, owner, call_args)
      end

      # Now we move out values to the variables. This can be done automatically
      # because if declared inside a while, for example, the variable is nilable.
      if has_out
        node.args.zip(call_args) do |node_arg, call_arg|
          if node_arg.out? && node_arg.is_a?(Var)
            node_var = context.vars[node_arg.name]
            assign node_var.pointer, node_var.type, node_arg.type, to_lhs(call_arg, node_arg.type)
          end
        end
      end

      false
    end

    def prepare_call_args(node, owner)
      has_out = false
      call_args = Array(LibLLVM::ValueRef).new(node.args.length + 1)

      # First self.
      if (obj = node.obj) && obj.type.passed_as_self?
        accept obj
        call_args << @last
      elsif owner.passed_as_self?
        if yield_scope = context.vars["%scope"]?
          call_args << yield_scope.pointer
        else
          call_args << llvm_self(owner)
        end
      end

      # Then the arguments.
      node.args.each_with_index do |arg, i|
        if arg.out?
          has_out = true
          case arg
          when Var
            # For out arguments we reserve the space. After the call
            # we move the value to the variable.
            call_args << alloca(llvm_type(arg.type))
          when InstanceVar
            call_args << instance_var_ptr(type, arg.name, llvm_self_ptr)
          else
            arg.raise "Bug: out argument was #{arg}"
          end
        else
          accept arg
          call_args << @last
        end
      end

      {call_args, has_out}
    end

    def codegen_call_with_block(node, block, self_type, call_args, old_context)
      context.block = block
      context.block_context = old_context
      context.vars = {} of String => LLVMVar
      context.type = self_type

      target_def = node.target_def

      alloca_vars target_def.vars, target_def
      create_local_copy_of_block_args(target_def, self_type, call_args)

      Phi.open(self, node) do |phi|
        context.return_phi = phi

        accept target_def.body

        unless block.breaks?
          phi.add @last, target_def.body.type?
        end
      end
    end

    def codegen_dispatch(node, target_defs)
      new_vars = context.vars.dup

      # Get type_id of obj or owner
      if node_obj = node.obj
        owner = node_obj.type
        accept node_obj
        obj_type_id = @last
      else
        owner = node.scope
        obj_type_id = llvm_self
      end
      obj_type_id = type_id(obj_type_id, owner)

      # Create self var if available
      if node_obj && node_obj.type.passed_as_self?
        new_vars["%self"] = LLVMVar.new(@last, node_obj.type, true)
      end

      # Get type if of args and create arg vars
      arg_type_ids = node.args.map_with_index do |arg, i|
        accept arg
        new_vars["%arg#{i}"] = LLVMVar.new(@last, arg.type, true)
        type_id(@last, arg.type)
      end

      # Reuse this call for each dispatch branch
      call = Call.new(node_obj ? Var.new("%self") : nil, node.name, Array(ASTNode).new(node.args.length) { |i| Var.new("%arg#{i}") }, node.block)
      call.scope = node.scope

      with_cloned_context do
        context.vars = new_vars

        Phi.open(self, node) do |phi|
          # Iterate all defs and check if any match the current types, given their ids (obj_type_id and arg_type_ids)
          target_defs.each do |a_def|
            result = match_type_id(owner, a_def.owner.not_nil!, obj_type_id)
            a_def.args.each_with_index do |arg, i|
              result = and(result, match_type_id(node.args[i].type, arg.type, arg_type_ids[i]))
            end

            current_def_label, next_def_label = new_blocks({"current_def", "next_def"})
            cond result, current_def_label, next_def_label

            position_at_end current_def_label

            # Prepare this specific call
            call.target_defs = [a_def] of Def
            call.obj.try &.set_type(a_def.owner)
            call.args.zip(a_def.args) do |call_arg, a_def_arg|
              call_arg.set_type(a_def_arg.type)
            end
            if (node_block = node.block) && node_block.break.type?
              call.set_type(@mod.type_merge [a_def.type, node_block.break.type] of Type)
            else
              call.set_type(a_def.type)
            end
            accept call

            phi.add @last, a_def.type
            position_at_end next_def_label
          end
          unreachable
        end
      end
    end

    def codegen_call(node, target_def, self_type, call_args)
      body = target_def.body
      if body.is_a?(Primitive)
        case body.name
        when :struct_hash, :struct_equals, :struct_to_s
          # Skip: we want a method body for these
        else
          # Change context type: faster then creating a new context
          old_type = context.type
          context.type = self_type
          codegen_primitive(body, target_def, call_args)
          context.type = old_type
          return
        end
      end

      func = target_def_fun(target_def, self_type)
      codegen_call_or_invoke(node, func, call_args, target_def.raises, target_def.type)
    end

    def codegen_call_or_invoke(node, func, call_args, raises, type)
      if raises && (handler = @exception_handlers.try &.last?)
        invoke_out_block = new_block "invoke_out"
        @last = @builder.invoke func, call_args, invoke_out_block, handler.catch_block
        position_at_end invoke_out_block
      else
        @last = call func, call_args
      end

      emit_debug_metadata node, @last if @debug

      case type
      when .no_return?
        unreachable
      when .passed_by_value?
        union = alloca llvm_type(type)
        store @last, union
        @last = union
      end

      @last
    end

    def emit_debug_metadata(node, value)
      # if value.is_a?(LibLLVM::ValueRef) && !LLVM.constant?(value) && !value.is_a?(LibLLVM::BasicBlockRef)
        if md = dbg_metadata(node)
          LibLLVM.set_metadata(value, @dbg_kind, md) rescue nil
        end
      # end
    end

    def emit_def_debug_metadata(target_def)
      unless target_def.name == MAIN_NAME
        if def_md = def_metadata(context.fun, target_def)
          @subprograms[@llvm_mod] ||= [] of LibLLVM::ValueRef?
          @subprograms[@llvm_mod] << def_md
        end
      end
    end

    def target_def_fun(target_def, self_type)
      mangled_name = target_def.mangled_name(self_type)
      self_type_mod = type_module(self_type)

      func = self_type_mod.functions[mangled_name]? || codegen_fun(mangled_name, target_def, self_type)
      check_mod_fun self_type_mod, mangled_name, func
    end

    def main_fun(name)
      func = @main_mod.functions[name]
      check_main_fun name, func
    end

    def check_main_fun(name, func)
      check_mod_fun @main_mod, name, func
    end

    def check_mod_fun(mod, name, func)
      return func if @llvm_mod == mod
      @llvm_mod.functions[name]? || declare_fun(name, func)
    end

    def declare_fun(mangled_name, func)
      new_fun = @llvm_mod.functions.add(
        mangled_name,
        func.param_types,
        func.return_type,
        func.varargs?
      )
      func.params.zip(new_fun.params) do |p1, p2|
        val = LLVM.get_attribute(p1)
        LLVM.add_attribute(p2, val) if val != 0
      end
      new_fun
    end

    def codegen_fun(mangled_name, target_def, self_type, is_exported_fun = false, fun_module = type_module(self_type), is_closure = false)
      old_position = insert_block
      old_entry_block = @entry_block
      old_alloca_block = @alloca_block
      old_exception_handlers = @exception_handlers
      old_trampoline_wrappes = @trampoline_wrappers
      old_llvm_mod = @llvm_mod

      with_cloned_context do
        context.type = self_type
        context.vars = {} of String => LLVMVar
        context.in_const_block = false

        @llvm_mod = fun_module

        @trampoline_wrappers = nil
        @exception_handlers = nil

        args = codegen_fun_signature(mangled_name, target_def, self_type, is_closure)

        if !target_def.is_a?(External) || is_exported_fun
          emit_def_debug_metadata target_def if @debug

          new_entry_block

          if is_closure && (context_closure_vars = context.closure_vars)
            setup_closure_vars context_closure_vars
          end

          alloca_vars target_def.vars, target_def, args
          create_local_copy_of_fun_args(target_def, self_type, args)

          context.return_type = target_def.type?
          context.return_phi = nil

          accept target_def.body

          codegen_return target_def.body.type?

          br_from_alloca_to_entry
        end

        position_at_end old_position

        @last = llvm_nil

        @llvm_mod = old_llvm_mod
        @exception_handlers = old_exception_handlers
        @trampoline_wrappers = old_trampoline_wrappes
        @entry_block = old_entry_block
        @alloca_block = old_alloca_block

        context.fun
      end
    end

    def codegen_fun_signature(mangled_name, target_def, self_type, is_closure)
      args = Array(Arg).new(target_def.args.length + 1)
      args.push Arg.new_with_type("self", self_type) if self_type.passed_as_self?
      args.concat target_def.args

      llvm_args_types = args.map { |arg| llvm_arg_type(arg.type) }
      if is_closure
        llvm_args_types << LLVM.pointer_type(context.closure_type.not_nil!)
      end

      context.fun = @llvm_mod.functions.add(
        mangled_name,
        llvm_args_types,
        llvm_type(target_def.type),
        target_def.varargs,
      )
      context.fun.add_attribute LibLLVM::Attribute::NoReturn if target_def.no_returns?

      if @single_module && !target_def.is_a?(External)
        context.fun.linkage = LibLLVM::Linkage::Internal
      end

      args.each_with_index do |arg, i|
        param = context.fun.get_param(i)
        LLVM.set_name param, arg.name

        # Set 'byval' attribute
        # but don't set it if it's the "self" argument and it's a struct.
        if arg.type.passed_by_value? && !(i == 0 && self_type.struct?)
          LLVM.add_attribute param, LibLLVM::Attribute::ByVal
        end
      end

      if is_closure
        LLVM.add_attribute context.fun.get_param(llvm_args_types.length - 1), LibLLVM::Attribute::Nest
      end

      args
    end

    def setup_closure_vars(closure_vars)
      closure_ptr = context.fun.get_param(context.fun.param_count - 1)
      closure_vars.each_with_index do |var, i|
        context.vars[var.name] = LLVMVar.new(gep(closure_ptr, 0, i), var.type)
      end
    end

    def create_local_copy_of_fun_args(target_def, self_type, args)
      target_def_vars = target_def.vars
      args.each_with_index do |arg, i|
        param = context.fun.get_param(i)
        if (i == 0 && self_type.passed_as_self?) || arg.type.passed_by_value?
          # TODO: check if the variable is closured
          context.vars[arg.name] = LLVMVar.new(param, arg.type, true)
        else
          create_local_copy_of_arg(target_def_vars, arg, param)
        end
      end
    end

    def create_local_copy_of_block_args(target_def, self_type, call_args)
      args_base_index = 0
      if self_type.passed_as_self?
        context.vars["self"] = LLVMVar.new(call_args[0], self_type, true)
        args_base_index = 1
      end

      target_def.args.each_with_index do |arg, i|
        create_local_copy_of_arg(target_def.vars, arg, call_args[args_base_index + i])
      end
    end

    def create_local_copy_of_arg(target_def_vars, arg, value)
      target_def_var = target_def_vars.try &.[arg.name]

      var_type = (target_def_var || arg).type
      if closure_var = context.vars[arg.name]?
        pointer = closure_var.pointer
      else
        # We don't need to create a copy of the argument if it's never
        # assigned a value inside the function.
        deps_count = target_def_var.try(&.dependencies?.try(&.length)) || 0
        needs_copy = deps_count > 1
        if needs_copy
          pointer = alloca(llvm_type(var_type), arg.name)
          context.vars[arg.name] = LLVMVar.new(pointer, var_type)
        else
          context.vars[arg.name] = LLVMVar.new(value, var_type, true)
          return
        end
      end

      assign pointer, var_type, arg.type, value
    end

    def type_id(value, type)
      case type
      when NilableType
        @builder.select null_pointer?(value), type_id(@mod.nil), type_id(type.not_nil_type)
      when ReferenceUnionType
        load(value)
      when NilableReferenceUnionType
        nil_block, not_nil_block, exit_block = new_blocks({"nil", "not_nil", "exit"})
        phi_table = LLVM::PhiTable.new

        cond null_pointer?(value), nil_block, not_nil_block

        position_at_end nil_block
        phi_table.add insert_block, type_id(@mod.nil)
        br exit_block

        position_at_end not_nil_block
        phi_table.add insert_block, load(value)
        br exit_block

        position_at_end exit_block
        phi LLVM::Int32, phi_table
      when MixedUnionType
        load(union_type_id(value))
      when HierarchyType
        load(value)
      when HierarchyMetaclassType
        value
      else
        type_id(type)
      end
    end

    def type_id(type)
      int(@llvm_id.type_id(type))
    end

    def match_type_id(type, restriction : Program, type_id)
      llvm_true
    end

    def match_type_id(type, restriction, type_id)
      case type
      when UnionType, HierarchyType, HierarchyMetaclassType
        match_any_type_id(restriction, type_id)
      else
        equal? type_id(restriction), type_id
      end
    end

    def codegen_cond(type : Type)
      case type
      when NilType
        llvm_false
      when BoolType
        @last
      when TypeDefType
        codegen_cond type.typedef
      when NilableType, NilableReferenceUnionType, PointerInstanceType
        not_null_pointer? @last
      when MixedUnionType
        has_nil = type.union_types.any? &.nil_type?
        has_bool = type.union_types.any? &.bool_type?

        cond = llvm_true

        if has_nil || has_bool
          type_id = load union_type_id(@last)

          if has_nil
            is_nil = equal? type_id, type_id(@mod.nil)
            cond = and cond, not(is_nil)
          end

          if has_bool
            value = load(bit_cast union_value(@last), pointer_type(LLVM::Int1))
            is_bool = equal? type_id, type_id(@mod.bool)
            cond = and cond, not(and(is_bool, not(value)))
          end
        end

        cond
      else
        llvm_true
      end
    end

    def assign(target_pointer, target_type, value_type, value)
      if target_type == value_type
        store to_rhs(value, target_type), target_pointer
      # Hack until we fix it in the type inference
      elsif value_type.is_a?(HierarchyType) && value_type.base_type == target_type
        # TODO: this should never happen, but it does. Sometimes we have:
        #
        #     def foo
        #       yield e
        #     end
        #
        #        foo do |x|
        #     end
        #
        # with e's type a HierarchyType and x's type its base type.
        #
        # I have no idea how to reproduce this, so this hack will remain here
        # until we figure it out.
        store cast_to(value, target_type), target_pointer
      else
        assign_distinct target_pointer, target_type, value_type, value
      end
    end

    def assign_distinct(target_pointer, target_type : NilableType, value_type : Type, value)
      store upcast(value, target_type, value_type), target_pointer
    end

    def assign_distinct(target_pointer, target_type : ReferenceUnionType, value_type : ReferenceUnionType, value)
      store value, target_pointer
    end

    def assign_distinct(target_pointer, target_type : ReferenceUnionType, value_type : HierarchyType, value)
      store value, target_pointer
    end

    def assign_distinct(target_pointer, target_type : ReferenceUnionType, value_type : Type, value)
      store cast_to(value, target_type), target_pointer
    end

    def assign_distinct(target_pointer, target_type : NilableReferenceUnionType, value_type : Type, value)
      store upcast(value, target_type, value_type), target_pointer
    end

    def assign_distinct(target_pointer, target_type : MixedUnionType, value_type : MixedUnionType, value)
      casted_value = cast_to_pointer value, target_type
      store load(casted_value), target_pointer
    end

    def assign_distinct(target_pointer, target_type : MixedUnionType, value_type : NilableType, value)
      store_in_union target_pointer, value_type, value
    end

    def assign_distinct(target_pointer, target_type : MixedUnionType, value_type : VoidType, value)
      store type_id(value_type), union_type_id(target_pointer)
    end

    def assign_distinct(target_pointer, target_type : MixedUnionType, value_type : Type, value)
      store_in_union target_pointer, value_type, to_rhs(value, value_type)
    end

    def assign_distinct(target_pointer, target_type : HierarchyType, value_type : MixedUnionType, value)
      casted_value = cast_to_pointer(union_value(value), target_type)
      store load(casted_value), target_pointer
    end

    def assign_distinct(target_pointer, target_type : HierarchyType, value_type : Type, value)
      store cast_to(value, target_type), target_pointer
    end

    def assign_distinct(target_pointer, target_type : HierarchyMetaclassType, value_type : MetaclassType, value)
      store value, target_pointer
    end

    def assign_distinct(target_pointer, target_type : Type, value_type : Type, value)
      raise "Bug: trying to assign #{target_type} <- #{value_type}"
    end

    def downcast(value, to_type, from_type : VoidType, already_loaded)
      value
    end

    def downcast(value, to_type, from_type : Type, already_loaded)
      value = to_lhs(value, from_type) unless already_loaded
      if from_type != to_type
        value = downcast_distinct value, to_type, from_type
      end
      value
    end

    def downcast_distinct(value, to_type, from_type : MetaclassType | GenericClassInstanceMetaclassType | HierarchyMetaclassType)
      value
    end

    def downcast_distinct(value, to_type : HierarchyType, from_type : HierarchyType)
      value
    end

    def downcast_distinct(value, to_type : MixedUnionType, from_type : HierarchyType)
      # This happens if the restriction is a union:
      # we keep each of the union types as the result, we don't fully merge
      union_ptr = alloca llvm_type(to_type)
      store_in_union union_ptr, from_type, value
      union_ptr
    end

    def downcast_distinct(value, to_type : ReferenceUnionType, from_type : HierarchyType)
      # This happens if the restriction is a union:
      # we keep each of the union types as the result, we don't fully merge
      value
    end

    def downcast_distinct(value, to_type : NonGenericClassType | GenericClassInstanceType, from_type : HierarchyType)
      cast_to value, to_type
    end

    def downcast_distinct(value, to_type : NilType, from_type : NilableType)
      llvm_nil
    end

    def downcast_distinct(value, to_type : Type, from_type : NilableType)
      value
    end

    def downcast_distinct(value, to_type : ReferenceUnionType, from_type : ReferenceUnionType)
      value
    end

    def downcast_distinct(value, to_type : HierarchyType, from_type : ReferenceUnionType)
      value
    end

    def downcast_distinct(value, to_type : Type, from_type : ReferenceUnionType)
      cast_to value, to_type
    end

    def downcast_distinct(value, to_type : HierarchyType, from_type : NilableReferenceUnionType)
      value
    end

    def downcast_distinct(value, to_type : ReferenceUnionType, from_type : NilableReferenceUnionType)
      value
    end

    def downcast_distinct(value, to_type : NilableType, from_type : NilableReferenceUnionType)
      cast_to value, to_type
    end

    def downcast_distinct(value, to_type : NilType, from_type : NilableReferenceUnionType)
      llvm_nil
    end

    def downcast_distinct(value, to_type : Type, from_type : NilableReferenceUnionType)
      cast_to value, to_type
    end

    def downcast_distinct(value, to_type : MixedUnionType, from_type : MixedUnionType)
      cast_to_pointer value, to_type
    end

    def downcast_distinct(value, to_type : NilableType, from_type : MixedUnionType)
      load cast_to_pointer(union_value(value), to_type)
    end

    def downcast_distinct(value, to_type : Type, from_type : MixedUnionType)
      value_ptr = union_value(value)
      value = cast_to_pointer(value_ptr, to_type)
      to_lhs value, to_type
    end

    def downcast_distinct(value, to_type : Type, from_type : Type)
      raise "Bug: trying to downcast #{to_type} <- #{from_type}"
    end

    def upcast(value, to_type, from_type)
      if to_type != from_type
        value = upcast_distinct(value, to_type, from_type)
      end
      value
    end

    def upcast_distinct(value, to_type : MetaclassType | GenericClassInstanceMetaclassType | HierarchyMetaclassType, from_type)
      value
    end

    def upcast_distinct(value, to_type : HierarchyType, from_type)
      cast_to value, to_type
    end

    def upcast_distinct(value, to_type : NilableType, from_type : NilType?)
      LLVM.null(llvm_type(to_type))
    end

    def upcast_distinct(value, to_type : NilableType, from_type : Type)
      value
    end

    def upcast_distinct(value, to_type : NilableReferenceUnionType, from_type : NilType?)
      LLVM.null(llvm_type(to_type))
    end

    def upcast_distinct(value, to_type : NilableReferenceUnionType, from_type : Type)
      cast_to value, to_type
    end

    def upcast_distinct(value, to_type : ReferenceUnionType, from_type)
      cast_to value, to_type
    end

    def upcast_distinct(value, to_type : MixedUnionType, from_type : MixedUnionType)
      cast_to_pointer value, to_type
    end

    def upcast_distinct(value, to_type : MixedUnionType, from_type : VoidType)
      union_ptr = alloca(llvm_type(to_type))
      store type_id(from_type), union_type_id(union_ptr)
      union_ptr
    end

    def upcast_distinct(value, to_type : MixedUnionType, from_type : Type)
      union_ptr = alloca(llvm_type(to_type))
      store_in_union(union_ptr, from_type, to_rhs(value, from_type))
      union_ptr
    end

    def upcast_distinct(value, to_type : Type, from_type : Type)
      raise "Bug: trying to upcast #{to_type} <- #{from_type}"
    end

    def match_any_type_id(type, type_id)
      # Special case: if the type is Object+ we want to match against Reference+,
      # because Object+ can only mean a Reference type (so we exclude Nil, for example).
      type = @mod.reference.hierarchy_type if type == @mod.object.hierarchy_type

      case type
      when UnionType
        match_any_type_id_with_function(type, type_id)
      when HierarchyMetaclassType
        match_any_type_id_with_function(type, type_id)
      when HierarchyType
        if type.base_type.subclasses.empty?
          equal? type_id(type.base_type), type_id
        else
          match_any_type_id_with_function(type, type_id)
        end
      else
        equal? type_id(type), type_id
      end
    end

    def match_any_type_id_with_function(type, type_id)
      match_fun_name = "~match<#{type}>"
      func = @main_mod.functions[match_fun_name]? || create_match_fun(match_fun_name, type)
      func = check_main_fun match_fun_name, func
      return call func, [type_id] of LibLLVM::ValueRef
    end

    def create_match_fun(name, type)
      old_builder = @builder
      old_llvm_mod = @llvm_mod
      @llvm_mod = @main_mod

      a_fun = @main_mod.functions.add(name, ([LLVM::Int32] of LibLLVM::TypeRef), LLVM::Int1) do |func|
        type_id = func.get_param(0)
        func.append_basic_block("entry") do |builder|
          @builder = builder
          create_match_fun_body(type, type_id)
        end
      end

      @builder = old_builder
      @llvm_mod = old_llvm_mod

      a_fun
    end

    def create_match_fun_body(type : UnionType, type_id)
      result = nil
      type.union_types.each do |sub_type|
        sub_type_cond = match_any_type_id(sub_type, type_id)
        result = result ? or(result, sub_type_cond) : sub_type_cond
      end
      ret result.not_nil!
    end

    def create_match_fun_body(type : HierarchyType, type_id)
      min_max = @llvm_id.min_max_type_id(type.base_type).not_nil!
      ret(
        and (builder.icmp LibLLVM::IntPredicate::SGE, type_id, int(min_max[0])),
                     (builder.icmp LibLLVM::IntPredicate::SLE, type_id, int(min_max[1]))
                  )
    end

    def create_match_fun_body(type, type_id)
      result = nil
      type.each_concrete_type do |sub_type|
        sub_type_cond = equal? type_id(sub_type), type_id
        result = result ? or(result, sub_type_cond) : sub_type_cond
      end
      ret result.not_nil!
    end

    def llvm_self(type = context.type)
      self_var = context.vars["self"]?
      if self_var
        downcast self_var.pointer, type, self_var.type, true
      else
        type_id(type.not_nil!)
      end
    end

    def llvm_self_ptr
      type = context.type
      if type.is_a?(HierarchyType)
        cast_to llvm_self, type.base_type
      else
        llvm_self
      end
    end

    def type_module(type)
      return @main_mod if @single_module

      @types_to_modules[type] ||= begin
        type = type.typedef if type.is_a?(TypeDefType)
        case type
        when Nil, Program, LibType
          type_name = ""
        else
          type_name = type.instance_type.to_s
        end

        @modules[type_name] ||= begin
          llvm_mod = LLVM::Module.new(type_name)
          define_symbol_table llvm_mod
          llvm_mod
        end
      end
    end

    def new_entry_block
      @alloca_block, @entry_block = new_entry_block_chain({"alloca", "entry"})
    end

    def new_entry_block_chain names
      blocks = new_blocks names
      position_at_end blocks.last
      blocks
    end

    def br_from_alloca_to_entry
      br_block_chain({@alloca_block, @entry_block})
    end

    def br_block_chain blocks
      old_block = insert_block

      0.upto(blocks.count - 2) do |i|
        position_at_end blocks[i]
        br blocks[i + 1]
      end

      position_at_end old_block
    end

    def new_block(name)
      context.fun.append_basic_block(name)
    end

    def new_blocks(names)
      names.map { |name| new_block name }
    end

    def alloca_vars(vars, obj = nil, args = nil)
      return unless vars

      in_alloca_block do
        closure_vars = nil

        # Allocate all variables which are not closured and don't belong to an outer closure
        vars.each do |name, var|
          next if name == "self" || context.vars[name]?

          var_type = var.type? || @mod.nil

          if var_type.void?
            context.vars[name] = LLVMVar.new(llvm_nil, @mod.void)
          elsif var.closure_in?(obj)
            closure_vars ||= [] of MetaVar
            closure_vars << var
          elsif !obj || var.belongs_to?(obj)
            # We deal with arguments later
            is_arg = args.try &.any? { |arg| arg.name == var.name }
            next if is_arg

            ptr = @builder.alloca llvm_type(var_type), name
            context.vars[name] = LLVMVar.new(ptr, var_type)

            # Assign default nil for variables that are bound to the nil variable
            if bound_to_mod_nil?(var)
              assign ptr, var_type, @mod.nil, llvm_nil
            end
          else
            # The variable belong to an outer closure
          end
        end

        # Alocate current closure
        if closure_vars
          closure_type = @llvm_typer.closure_context_type(closure_vars)
          closure_ptr = malloc closure_type
          closure_vars.each_with_index do |var, i|
            context.vars[var.name] = LLVMVar.new(gep(closure_ptr, 0, i), var.type)
          end
          context.closure_vars = closure_vars
          context.closure_type = closure_type
          context.closure_ptr = closure_ptr
        else
          context.closure_vars = nil
          context.closure_type = nil
          context.closure_ptr = nil
        end
      end
    end

    def reset_block_vars(block)
      vars = block.before_vars
      return unless vars

      vars.each do |name, var|
        if var.context == block && bound_to_mod_nil?(var)
          context_var = context.vars[name]
          assign context_var.pointer, context_var.type, @mod.nil, llvm_nil
        end
      end
    end

    def bound_to_mod_nil?(var)
      var.dependencies.any? &.same?(@mod.nil_var)
    end

    def alloca(type, name = "")
      in_alloca_block { @builder.alloca type, name }
    end

    def in_alloca_block
      old_block = insert_block
      if context.in_const_block
        position_at_end @main_alloca_block
      else
        position_at_end @alloca_block
      end
      value = yield
      position_at_end old_block
      value
    end

    def in_const_block(const_block_name)
      old_position = insert_block
      old_llvm_mod = @llvm_mod
      old_exception_handlers = @exception_handlers

      with_cloned_context do
        context.fun = @main
        context.in_const_block = true

        @exception_handlers = nil
        @llvm_mod = @main_mod

        const_block = new_block const_block_name
        position_at_end const_block

        yield

        new_const_block = insert_block
        position_at_end @const_block
        br const_block
        @const_block = new_const_block

        position_at_end old_position
      end

      @llvm_mod = old_llvm_mod
      @exception_handlers = old_exception_handlers
    end

    def printf(format, args = [] of LibLLVM::ValueRef)
      call @mod.printf(@llvm_mod), [@builder.global_string_pointer(format)] + args
    end

    def allocate_aggregate(type)
      struct_type = llvm_struct_type(type)
      if type.struct?
        @last = alloca struct_type
      else
        @last = malloc struct_type
      end
      memset @last, int8(0), size_of(struct_type)
      @last
    end

    def allocate_tuple(type)
      struct_type = alloca llvm_type(type)
      type.tuple_types.each_with_index do |tuple_type, i|
        exp_type, value = yield tuple_type, i
        assign aggregate_index(struct_type, i), tuple_type, exp_type, value
      end
      struct_type
    end

    def malloc(type)
      @malloc_fun ||= @main_mod.functions[MALLOC_NAME]?
      if malloc_fun = @malloc_fun
        malloc_fun = check_main_fun MALLOC_NAME, malloc_fun
        size = trunc(size_of(type), LLVM::Int32)
        pointer = call malloc_fun, [size]
        bit_cast pointer, pointer_type(type)
      else
        @builder.malloc type
      end
    end

    def array_malloc(type, count)
      @malloc_fun ||= @main_mod.functions[MALLOC_NAME]?
      if malloc_fun = @malloc_fun
        malloc_fun = check_main_fun MALLOC_NAME, malloc_fun
        size = trunc(size_of(type), LLVM::Int32)
        count = trunc(count, LLVM::Int32)
        size = @builder.mul size, count
        pointer = call malloc_fun, [size]
        bit_cast pointer, pointer_type(type)
      else
        @builder.array_malloc(type, count)
      end
    end

    def memset(pointer, value, size)
      pointer = cast_to_void_pointer pointer
      call @mod.memset(@llvm_mod), [pointer, value, trunc(size, LLVM::Int32), int32(4), int1(0)]
    end

    def realloc(buffer, size)
      @realloc_fun ||= @main_mod.functions[REALLOC_NAME]?
      if realloc_fun = @realloc_fun
        realloc_fun = check_main_fun REALLOC_NAME, realloc_fun
        size = trunc(size, LLVM::Int32)
        call realloc_fun, [buffer, size]
      else
        call @mod.realloc(@llvm_mod), [buffer, size]
      end
    end

    def to_lhs(value, type)
      type.passed_by_value? ? value : load value
    end

    def to_rhs(value, type)
      type.passed_by_value? ? load value : value
    end

    def union_type_id(union_pointer)
      aggregate_index union_pointer, 0
    end

    def union_value(union_pointer)
      aggregate_index union_pointer, 1
    end

    def store_in_union(union_pointer, value_type, value)
      store type_id(value, value_type), union_type_id(union_pointer)
      casted_value_ptr = cast_to_pointer(union_value(union_pointer), value_type)
      store value, casted_value_ptr
    end

    def aggregate_index(ptr, index)
      gep ptr, 0, index
    end

    def instance_var_ptr(type, name, pointer)
      index = type.index_of_instance_var(name)

      unless type.struct?
        index += 1
      end

      if type.is_a?(HierarchyType)
        pointer = cast_to pointer, type.base_type
      end

      aggregate_index pointer, index
    end

    def build_string_constant(str, name = "str")
      name = name.replace '@', '.'
      key = StringKey.new(@llvm_mod, str)
      @strings[key] ||= begin
        global = @llvm_mod.globals.add(LLVM.struct_type([LLVM::Int32, LLVM::Int32, LLVM.array_type(LLVM::Int8, str.length + 1)]), name)
        LLVM.set_linkage global, LibLLVM::Linkage::Private
        LLVM.set_global_constant global, true
        LLVM.set_initializer global, LLVM.struct([type_id(@mod.string), int32(str.length), LLVM.string(str)])
        cast_to global, @mod.string
      end
    end

    class Context
      property :fun
      property type
      property vars
      property return_type
      property return_phi
      property break_phi
      property next_phi
      property while_block
      property while_exit_block
      property! block
      property! block_context
      property in_const_block
      property closure_vars
      property closure_type
      property closure_ptr

      def initialize(@fun, @type, @vars = {} of String => LLVMVar)
        @in_const_block = false
      end

      def block_returns?
        (block = @block) && (block_context = @block_context) && (block.returns? || (block.yields? && block_context.block_returns?))
      end

      def block_breaks?
        (block = @block) && (block_context = @block_context) && (block.breaks? || (block.yields? && block_context.block_breaks?))
      end

      def clone
        context = Context.new @fun, @type, @vars
        context.return_type = @return_type
        context.return_phi = @return_phi
        context.break_phi = @break_phi
        context.next_phi = @next_phi
        context.while_block = @while_block
        context.while_exit_block = @while_exit_block
        context.block = @block
        context.block_context = @block_context
        context.in_const_block = @in_const_block
        context.closure_vars = @closure_vars
        context.closure_type = @closure_type
        context.closure_ptr = @closure_ptr
        context
      end
    end

    class Phi
      include LLVMBuilderHelper

      getter node
      getter count
      getter exit_block

      def self.open(codegen, node)
        block = new codegen, node
        yield block
        block.close
      end

      def initialize(@codegen, @node)
        @phi_table = LLVM::PhiTable.new
        @exit_block = @codegen.new_block "exit"
        @count = 0
      end

      def builder
        @codegen.builder
      end

      def llvm_typer
        @codegen.llvm_typer
      end

      def add(value, type : Nil)
        unreachable
      end

      def add(value, type : NoReturnType)
        unreachable
      end

      def add(value, type : Type)
        unless node.type.void?
          value = @codegen.upcast value, node.type, type
          @phi_table.add insert_block, value
        end
        @count += 1
        br exit_block
      end

      def close
        position_at_end exit_block
        if node.returns? || node.no_returns?
          unreachable
        else
          if @count == 0
            unreachable
          elsif @phi_table.empty?
            # All branches are void or no return
            @codegen.last = llvm_nil
          else
            @codegen.last = phi llvm_arg_type(@node.type), @phi_table
          end
        end
        @codegen.last
      end
    end

    def with_cloned_context(new_context = @context)
      with_context(new_context.clone) { |ctx| yield ctx }
    end

    def with_context(new_context)
      old_context = @context
      @context = new_context
      value = yield old_context
      @context = old_context
      value
    end

    def accept(node)
      node.accept self
    end

    def block_returns?
      context.block_returns?
    end

    def block_breaks?
      context.block_breaks?
    end
  end
end
