require "parser"
require "type_inference"
require "visitor"
require "llvm"
require "codegen/*"
require "program"

LLVM.init_x86

module Crystal
  DUMP_LLVM = ENV["DUMP"] == "1"
  MAIN_NAME = "__crystal_main"
  RAISE_NAME = "__crystal_raise"
  MALLOC_NAME = "__crystal_malloc"
  REALLOC_NAME = "__crystal_realloc"

  class Program
    def run(code)
      node = Parser.parse(code)
      node = normalize node
      node = infer_type node
      load_libs
      evaluate node
    end

    def evaluate(node)
      llvm_mod = build(node, true)[""]
      llvm_mod.verify
      engine = LLVM::JITCompiler.new(llvm_mod)

      argc = LibLLVM.create_generic_value_of_int(LLVM::Int32, 0_u64, 1)
      argv = LibLLVM.create_generic_value_of_pointer(nil)

      engine.run_function llvm_mod.functions[MAIN_NAME], [argc, argv]
    end

    def build(node, single_module = false, llvm_mod = LLVM::Module.new("main_module"))
      visitor = CodeGenVisitor.new(self, node, llvm_mod, single_module)
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

    class LLVMVar
      getter pointer
      getter type
      getter treated_as_pointer

      def initialize(@pointer, @type, @treated_as_pointer = false)
      end
    end

    make_tuple Handler, node, catch_block, vars
    make_tuple StringKey, mod, string

    def initialize(@mod, @node, @llvm_mod, @single_module = false, @use_host_flags = false)
      @main_mod = @llvm_mod
      @llvm_typer = LLVMTyper.new
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

      @modules = {"" => @main_mod} of String => LLVM::Module

      @alloca_block, @const_block, @entry_block = new_entry_block_chain ["alloca", "const", "entry"]
      @main_alloca_block = @alloca_block

      @const_block_entry = @const_block
      @exception_handlers = [] of Handler
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
      @in_const_block = false
      @trampoline_wrappers = {} of UInt64 => LLVM::Function
      @fun_literal_count = 0

      setup_context_return context, @main_ret_type
    end

    def define_symbol_table(llvm_mod)
      llvm_mod.globals.add(LLVM.array_type(llvm_type(@mod.string), @symbol_table_values.count), "symbol_table")
    end

    def type
      context.type.not_nil!
    end

    def finish
      br_block_chain [@alloca_block, @const_block_entry]
      br_block_chain [@const_block, @entry_block]
      codegen_return(@main_ret_type, @main_ret_type) { |value| ret value }
      @llvm_mod.dump if DUMP_LLVM
    end

    def visit(node : FunDef)
      unless node.external.dead
        codegen_fun node.real_name, node.external, @mod, true
      end

      false
    end

    # Can only happen in a Const or as an argument cast
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
              when :byte_size
                codegen_primitive_byte_size node, target_def, call_args
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
        store int32(base_type.type_id), type_id_ptr
      end

      if type.is_a?(HierarchyType)
        @last = box_object_in_hierarchy(base_type, type, @last, false)
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
      size = call_args[1]
      size = @builder.mul size, llvm_size(type.element_type)
      reallocated_ptr = realloc casted_ptr, size
      @last = cast_to_pointer reallocated_ptr, type.element_type
    end

    def codegen_primitive_pointer_add(node, target_def, call_args)
      @last = gep call_args[0], call_args[1]
    end

    def codegen_primitive_byte_size(node, target_def, call_args)
      llvm_size(type.instance_type)
    end

    def codegen_primitive_struct_new(node, target_def, call_args)
      allocate_aggregate (node.type as PointerInstanceType).element_type
    end

    def codegen_primitive_struct_set(node, target_def, call_args)
      type = context.type as CStructType

      name = target_def.name[0 .. -2]

      value = to_rhs call_args[1], node.type

      ptr = struct_field_ptr(type, name, call_args[0])
      store value, ptr

      call_args[1]
    end

    def codegen_primitive_struct_get(node, target_def, call_args)
      type = context.type as CStructType
      name = target_def.name
      to_lhs struct_field_ptr(type, name, call_args[0]), node.type
    end

    def struct_field_ptr(type, field_name, pointer)
      index = type.index_of_var(field_name)
      aggregate_index pointer, index
    end

    def codegen_primitive_union_new(node, target_def, call_args)
      allocate_aggregate (node.type as PointerInstanceType).element_type
    end

    def codegen_primitive_union_set(node, target_def, call_args)
      type = context.type as CUnionType

      name = target_def.name[0 .. -2]

      value = to_rhs call_args[1], node.type

      ptr = union_field_ptr(node, call_args[0])
      store value, ptr

      call_args[1]
    end

    def codegen_primitive_union_get(node, target_def, call_args)
      type = context.type as CUnionType
      to_lhs union_field_ptr(node, call_args[0]), node.type
    end

    def union_field_ptr(node, pointer)
      ptr = aggregate_index pointer, 0
      cast_to_pointer ptr, node.type
    end

    def codegen_primitive_external_var_set(node, target_def, call_args)
      name = (target_def as External).real_name
      var = declare_lib_var name, node.type
      @last = call_args[0]
      store @last, var
      @last
    end

    def codegen_primitive_external_var_get(node, target_def, call_args)
      name = (target_def as External).real_name
      var = declare_lib_var name, node.type
      load var
    end

    def codegen_primitive_object_id(node, target_def, call_args)
      obj = call_args[0]
      obj = load(union_value obj) if type.hierarchy?
      ptr2int obj, LLVM::Int64
    end

    def codegen_primitive_object_to_cstr(node, target_def, call_args)
      obj = call_args[0]
      obj = load(union_value obj) if type.hierarchy?
      buffer = array_malloc(LLVM::Int8, int(context.type.to_s.length + 23))
      call @mod.sprintf(@llvm_mod), [buffer, @builder.global_string_pointer("<#{context.type}:0x%016lx>"), obj] of LibLLVM::ValueRef
      buffer
    end

    def codegen_primitive_object_crystal_type_id(node, target_def, call_args)
      int(type.type_id)
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
        int(node.type.type_id)
      end
    end

    def codegen_primitive_fun_call(node, target_def, call_args)
      codegen_call_or_invoke(call_args[0], call_args[1 .. -1], true, target_def.type)
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

    def visit(node : PointerOf)
      node_exp = node.exp
      @last = case node_exp
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
      the_fun = codegen_fun(fun_literal_name, node.def, @mod, false, @main_mod)
      @last = (check_main_fun fun_literal_name, the_fun).fun

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
        tramp_ptr = array_malloc(LLVM::Int8, int(32))
        call @mod.trampoline_init(@llvm_mod), [
          tramp_ptr,
          bit_cast(wrapper.fun, pointer_type(LLVM::Int8)),
          bit_cast(call_self, pointer_type(LLVM::Int8))
        ]
        @last = call @mod.trampoline_adjust(@llvm_mod), [tramp_ptr]
        @last = cast_to @last, node.type
      end

      false
    end

    def trampoline_wrapper(target_def, target_fun)
      key = target_def.object_id
      @trampoline_wrappers[key] ||= begin
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

    def visit(node : CastFunToReturnVoid)
      accept node.node

      node_type = node.node.type as FunType

      types = node_type.arg_types.dup
      types << @mod.void
      type = @mod.fun_of types

      @last = cast_to @last, type
    end

    def visit(node : Expressions)
      node.expressions.each do |exp|
        accept exp
        break if exp.no_returns? || exp.returns? || exp.breaks? || (exp.yields? && (block_returns? || block_breaks?))
      end
      false
    end

    def end_visit(node : Return)
      if handler = @exception_handlers.last?
        if node_ensure = handler.node.ensure
          old_last = @last
          with_cloned_context do
            context.vars = handler.vars
            accept node_ensure
          end
          @last = old_last
        end
      end

      exp_type = control_expression_type(node)
      return_type = context.return_type.not_nil!

      codegen_return(exp_type, return_type) do |value|
        if return_block = context.return_block
          context.return_block_table.not_nil!.add(insert_block, value) if value
          br return_block
        else
          ret value
        end
      end
    end

    def codegen_return(exp_type, fun_type)
      case fun_type
      when VoidType
        yield nil
      when NoReturnType
        unreachable
      when .passed_by_value?
        return_union = context.return_union.not_nil!
        assign(return_union, fun_type, exp_type.not_nil!, @last)
        yield load(return_union)
      when NilableType
        yield to_nilable(@last, fun_type, exp_type)
      else
        yield to_rhs(@last, fun_type)
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
      @last = int(node.type.type_id)
      false
    end

    def visit(node : Include)
      @last = llvm_nil
      false
    end

    def visit(node : If)
      then_block, else_block = new_blocks ["then", "else"]

      codegen_cond_branch node.cond, then_block, else_block

      branch = new_branched_block node
      codegen_if_branch branch, node.then, then_block
      codegen_if_branch branch, node.else, else_block
      close_branched_block branch

      false
    end

    def codegen_if_branch(branch, node, branch_block)
      position_at_end branch_block
      accept node
      add_branched_block_value(branch, node.type?, @last)
      br branch.exit_block
    end

    def visit(node : While)
      with_cloned_context do
        context.break_type = nil
        context.break_table = nil
        context.break_union = nil

        while_block, body_block, exit_block = new_blocks ["while", "body", "exit"]

        context.while_block = while_block
        context.while_exit_block = exit_block

        br node.run_once ? body_block : while_block

        position_at_end while_block

        codegen_cond_branch node.cond, body_block, exit_block

        position_at_end body_block
        accept node.body
        br while_block

        position_at_end exit_block
        unreachable if node.no_returns? || (node.body.yields? && block_breaks?)

        @last = llvm_nil
      end

      false
    end

    def codegen_cond_branch(node_cond, then_block, else_block)
      accept node_cond
      cond codegen_cond(node_cond.type), then_block, else_block

      nil
    end

    def codegen_cond(node : ASTNode)
      accept node
      codegen_cond node.type
    end

    def codegen_cond(type : NilType)
      llvm_nil
    end

    def codegen_cond(type : BoolType)
      @last
    end

    def codegen_cond(type : NilableType)
      not_null_pointer?(@last)
    end

    def codegen_cond(type : UnionType)
      has_nil = type.union_types.any? &.nil_type?
      has_bool = type.union_types.any? &.bool_type?

      # TODO: recheck this logic, I think it's wrong
      if has_nil || has_bool
        type_id = load union_type_id(@last)
        value = load(bit_cast union_value(@last), pointer_type(LLVM::Int1))

        is_nil = equal? type_id, int(@mod.nil.type_id)
        is_bool = equal? type_id, int(@mod.bool.type_id)
        is_false = equal? value, llvm_false
        cond = not(or(is_nil, and(is_bool, is_false)))
      elsif has_nil
        type_id = load union_type_id(@last)
        cond = not_equal? type_id, int(@mod.nil.type_id)
      elsif has_bool
        type_id = load union_type_id(@last)
        value = load(bit_cast union_value(@last), pointer_type(LLVM::Int1))

        is_bool = equal? type_id, int(@mod.bool.type_id)
        is_false = equal? value, llvm_false
        cond = not(and(is_bool, is_false))
      else
        cond = llvm_true
      end
    end

    def codegen_cond(type : PointerInstanceType)
      not_null_pointer?(@last)
    end

    def codegen_cond(type : TypeDefType)
      codegen_cond type.typedef
    end

    def codegen_cond(node_cond)
      llvm_true
    end

    def visit(node : Break)
      if node.exps.empty?
        @last = llvm_nil
      else
        accept node.exps.first
      end

      if break_type = context.break_type
        case break_type
        when .represented_as_union?
          break_union = context.break_union.not_nil!
          assign(break_union, break_type, control_expression_type(node), @last)
        when NilableType
          context.break_table.not_nil!.add insert_block, to_nilable(@last, break_type, control_expression_type(node))
        else
          context.break_table.not_nil!.add insert_block, @last
        end
      end

      br context.while_exit_block.not_nil!

      false
    end

    def end_visit(node : Next)
      if while_block = context.while_block
        br while_block
      end
    end

    def control_expression_type(node)
      node.exps.first?.try &.type? || @mod.nil
    end

    abstract class BranchedBlock
      include LLVMBuilderHelper

      property node
      property count
      property exit_block

      def initialize(@node, @exit_block, @codegen)
        @count = 0
      end

      def builder
        @codegen.builder
      end
    end

    class UnionBranchedBlock < BranchedBlock
      def initialize(node, exit_block, codegen)
        super
        @union_ptr = @codegen.alloca(@codegen.llvm_type(node.type))
      end

      def add_value(block, type, value)
        @codegen.assign(@union_ptr, @node.type, type, value)
        @count += 1
      end

      def close
        @union_ptr
      end
    end

    class PhiBranchedBlock < BranchedBlock
      def initialize(node, exit_block, codegen)
        super
        @phi_table = LLVM::PhiTable.new
      end

      def add_value(block, type, value)
        if @node.type.nilable?
          @phi_table.add block, @codegen.to_nilable(value, node.type, type)
        else
          @phi_table.add block, @codegen.to_rhs(value, type)
        end
        @count += 1
      end

      def close
        if @count == 0
          unreachable
        elsif @phi_table.empty?
          # All branches are void or no return
          @codegen.llvm_nil
        else
          phi @codegen.llvm_type(@node.type), @phi_table
        end
      end
    end

    def new_branched_block(node)
      exit_block = new_block("exit")
      if node.type?.try &.passed_by_value?
        UnionBranchedBlock.new node, exit_block, self
      else
        PhiBranchedBlock.new node, exit_block, self
      end
    end

    def add_branched_block_value(branch, type : Nil, value)
      unreachable
    end

    def add_branched_block_value(branch, type : NoReturnType, value)
      unreachable
    end

    def add_branched_block_value(branch, type : VoidType, value)
      branch.count += 1
    end

    def add_branched_block_value(branch, type : Type, value)
      branch.add_value insert_block, type, value
      br branch.exit_block
    end

    def close_branched_block(branch)
      position_at_end branch.exit_block
      if branch.node.returns? || branch.node.no_returns?
        unreachable
      else
        branch_value = branch.close
        if branch_value
          @last = branch_value
        end
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

      ptr = case target
            when InstanceVar
              instance_var_ptr (context.type as InstanceVarContainer), target.name, llvm_self_ptr
            when Global
              get_global target.name, target.type
            when ClassVar
              get_global class_var_global_name(target), target.type
            when Var
              if target.type.void?
                context.vars[target.name] = LLVMVar.new(llvm_nil, @mod.void)
                return
              end

              declare_var(target).pointer
            else
              raise "Unknown assign target in codegen: #{target}"
            end

      assign ptr, target.type, value.type, @last

      false
    end

    def get_global(name, type)
      ptr = @llvm_mod.globals[name]?
      unless ptr
        llvm_type = llvm_type(type)
        ptr = @llvm_mod.globals.add(llvm_type, name)
        if @llvm_mod == @main_mod
          LLVM.set_initializer ptr, LLVM.null(llvm_type)
        else
          LLVM.set_linkage ptr, LibLLVM::Linkage::External
        end
      end
      ptr
    end

    def class_var_global_name(node)
      "#{node.owner}#{node.var.name.replace('@', ':')}"
    end

    def visit(node : DeclareVar)
      var = node.var
      if var.is_a?(Var)
        declare_var var
      end
      false
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
        union_ptr = union_value value
        union_ptr = cast_to_pointer union_ptr, target_type
        union = load(union_ptr)
        store union, target_pointer
      else
        assign_distinct target_pointer, target_type, value_type, value
      end
    end

    def assign_distinct(target_pointer, target_type : HierarchyTypeMetaclass, value_type : Metaclass, value)
      store value, target_pointer
    end

    def assign_distinct(target_pointer, target_type : NilableType, value_type : Type, value)
      store to_nilable(value, target_type, value_type), target_pointer
    end

    def assign_distinct(target_pointer, target_type : UnionType | HierarchyType, value_type : UnionType | HierarchyType, value)
      casted_value = cast_to_pointer value, target_type
      store load(casted_value), target_pointer
    end

    def assign_distinct(target_pointer, target_type : UnionType, value_type : NilableType, value)
      type_id_ptr, value_ptr = union_type_id_and_value(target_pointer)

      type_id = type_id(value, value_type)
      store type_id, type_id_ptr

      casted_value_ptr = cast_to_pointer value_ptr, value_type.not_nil_type
      store value, casted_value_ptr
    end

    def assign_distinct(target_pointer, target_type : UnionType | HierarchyType, value_type : VoidType, value)
      store int(value_type.type_id), union_type_id(target_pointer)
    end

    def assign_distinct(target_pointer, target_type : UnionType | HierarchyType, value_type : Type, value)
      type_id_ptr, value_ptr = union_type_id_and_value(target_pointer)

      store int(value_type.type_id), type_id_ptr

      casted_value_ptr = cast_to_pointer(value_ptr, value_type)
      store to_rhs(value, value_type), casted_value_ptr
    end

    def assign_distinct(target_pointer, target_type : Type, value_type : Type, value)
      raise "Bug: trying to assign #{target_type} = #{value_type}"
    end

    def visit(node : Var)
      var = context.vars[node.name]
      @last = cast_value(var.pointer, node.type, var.type, var.treated_as_pointer)
    end

    def cast_value(value, to_type, from_type, treated_as_pointer = false)
      if from_type.void?
        # Nothing to do
      elsif from_type == to_type
        value = to_lhs value, from_type unless treated_as_pointer
      elsif from_type.is_a?(NilableType)
        if to_type.nil_type?
          value = llvm_nil
        else
          value = load value unless treated_as_pointer
        end
      elsif from_type.metaclass?
        # Nothing to do
      elsif to_type.represented_as_union?
        value = cast_to_pointer value, to_type
      else
        value_ptr = union_value(value)
        value = cast_to_pointer(value_ptr, to_type)
        value = to_lhs value, to_type
      end
      value
    end

    def box_object_in_hierarchy(object, hierarchy, value, load = true)
      hierarchy_type = alloca llvm_type(hierarchy)
      type_id_ptr, value_ptr = union_type_id_and_value(hierarchy_type)

      store int(object.type_id), type_id_ptr

      store cast_to_void_pointer(value), value_ptr
      if load
        load(hierarchy_type)
      else
        hierarchy_type
      end
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
      @last = instance_var_ptr type, node.name, llvm_self_ptr

      if ivar.type.passed_by_value?
        unless node.type == ivar.type
          if node.type.represented_as_union?
            @last = cast_to_pointer @last, node.type
          else
            value_ptr = union_value(@last)
            @last = cast_to_pointer value_ptr, node.type
            @last = load @last
          end
        end
      else
        @last = load @last
      end
    end

    def visit(node : IsA)
      const_type = node.const.type.instance_type
      codegen_type_filter node, &.implements?(const_type)
    end

    def visit(node : Cast)
      accept node.obj
      last_value = @last

      obj_type = node.obj.type
      to_type = node.to.type.instance_type

      case obj_type
      when .pointer?
        @last = cast_to last_value, to_type
      when .represented_as_union?
        resulting_type = obj_type.filter_by(to_type).not_nil!
        type_id_ptr = union_type_id last_value
        type_id = load type_id_ptr

        cmp = match_any_type_id resulting_type, type_id

        matches_block, doesnt_match_block = new_blocks ["matches", "doesnt_match"]
        cond cmp, matches_block, doesnt_match_block

        position_at_end doesnt_match_block
        accept type_cast_exception_call

        position_at_end matches_block
        @last = cast_value last_value, resulting_type, obj_type
      else
        # Nothing to do
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

    def visit(node : RespondsTo)
      name = node.name.value
      codegen_type_filter node, &.has_def?(name)
    end

    def codegen_type_filter(node)
      accept node.obj

      obj_type = node.obj.type

      case obj_type
      when HierarchyType
        codegen_type_filter_many_types(obj_type.concrete_types) { |type| yield type }
      when NilableType
        np = null_pointer?(@last)
        nil_matches = yield @mod.nil
        other_matches = yield obj_type.not_nil_type
        @last = or(
          and(np, int1(nil_matches ? 1 : 0)),
          and(not(np), int1(other_matches ? 1 : 0))
        )
      when UnionType
        codegen_type_filter_many_types(obj_type.concrete_types) { |type| yield type }
      else
        matches = yield obj_type
        @last = int1(matches ? 1 : 0)
      end

      false
    end

    def codegen_type_filter_many_types(types)
      matching_ids = types.select { |t| yield t }.map { |t| int32(t.type_id) }
      case matching_ids.length
      when 0
        @last = llvm_false
      when types.count
        @last = llvm_true
      else
        type_id = load union_type_id(@last)

        result = nil
        matching_ids.each do |matching_id|
          cmp = equal? type_id, matching_id
          result = result ? or(result, cmp) : cmp
        end
        @last = result.not_nil!
      end
    end

    def declare_var(var)
      context.vars[var.name] ||= LLVMVar.new(alloca(llvm_type(var.type), var.name), var.type)
    end

    def declare_lib_var(name, type)
      unless var = @lib_vars[name]?
        var = @llvm_mod.globals.add(llvm_type(type), name)
        LLVM.set_linkage var, LibLLVM::Linkage::External
        LLVM.set_thread_local var if @mod.has_flag?("linux")
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
        @last = int(node.type.type_id)
      end
      false
    end

    class Context
      property :fun
      property type
      property vars
      property return_block
      property return_block_table
      property return_type
      property return_union
      property break_table
      property break_type
      property break_union
      property while_block
      property while_exit_block
      property! block
      property! block_context

      def initialize(@fun, @type, @vars = {} of String => LLVMVar)
      end

      def block_returns?
        (block = @block) && (block_context = @block_context) && (block.returns? || (block.yields? && block_context.block_returns?))
      end

      def block_breaks?
        (block = @block) && (block_context = @block_context) && (block.breaks? || (block.yields? && block_context.block_breaks?))
      end

      def clone
        context = Context.new @fun, @type, @vars
        context.return_block = return_block
        context.return_block_table = return_block_table
        context.return_type = return_type
        context.return_union = return_union
        context.break_table = break_table
        context.break_type = break_type
        context.break_union = break_union
        context.while_block = while_block
        context.while_exit_block = while_exit_block
        context.block = @block
        context.block_context = @block_context
        context
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

    def block_returns?
      context.block_returns?
    end

    def block_breaks?
      context.block_breaks?
    end

    def visit(node : Yield)
      if block_context = context.block_context?
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

        with_cloned_context(block_context) do |old|
          context.vars = new_vars
          context.break_table = old.return_block_table
          context.break_type = old.return_type
          context.break_union = old.return_union
          context.while_exit_block = old.return_block
          accept block
        end

        if !node.type? || node.type.nil_type?
          @last = llvm_nil
        end
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
      branch = new_branched_block(node)

      @exception_handlers << Handler.new(node, catch_block, context.vars)
      accept node.body
      @exception_handlers.pop

      if node_else = node.else
        accept node_else
        add_branched_block_value branch, node_else.type, @last
      else
        add_branched_block_value branch, node.body.type, @last
      end

      br branch.exit_block

      position_at_end catch_block
      lp_ret_type = llvm_typer.landing_pad_type
      lp = @builder.landing_pad lp_ret_type, main_fun(PERSONALITY_NAME).fun, [] of LibLLVM::ValueRef
      unwind_ex_obj = @builder.extract_value lp, 0
      ex_type_id = @builder.extract_value lp, 1

      if node_rescues = node.rescues
        node_rescues.each do |a_rescue|
          this_rescue_block, next_rescue_block = new_blocks ["this_rescue", "next_rescue"]
          if a_rescue_types = a_rescue.types
            cond = nil
            a_rescue_types.each do |type|
              rescue_type = type.type.instance_type.hierarchy_type
              rescue_type_cond = match_any_type_id(rescue_type, ex_type_id.not_nil!)
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

              exception = int2ptr exception_ptr, pointer_type(LLVM::Int8)
              ex_union = alloca llvm_type(a_rescue.type)
              ex_union_type_ptr, ex_union_value_ptr = union_type_id_and_value(ex_union)
              store ex_type_id, ex_union_type_ptr
              store exception, ex_union_value_ptr
              context.vars[a_rescue_name] = LLVMVar.new(ex_union, a_rescue.type)
            end

            accept a_rescue.body
          end
          add_branched_block_value branch, a_rescue.body.type, @last
          br branch.exit_block

          position_at_end next_rescue_block
        end
      end

      if node_ensure = node.ensure
        accept node_ensure
      end

      raise_fun = main_fun(RAISE_NAME)
      codegen_call_or_invoke(raise_fun, [bit_cast(unwind_ex_obj, type_of(raise_fun.get_param(0)))], true, @mod.no_return)

      close_branched_block(branch)
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
          raise "Bug: #{node} had a wrong type (#{element_type})"
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

      call_args = prepare_call_args node, owner

      return if node.args.any?(&.yields?) && block_breaks?

      with_cloned_context do |old_context|
        if block = node.block
          codegen_call_with_block(node, block, owner, call_args, old_context)
        else
          context.return_block = nil
          context.return_block_table = nil
          context.break_table = nil
          codegen_call(node, owner, call_args)
        end
      end

      false
    end

    def prepare_call_args(node, owner)
      call_args = [] of LibLLVM::ValueRef

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
          case arg
          when Var
            declare_var(arg)
            call_args << context.vars[arg.name].pointer
          when InstanceVar
            call_args << instance_var_ptr(type, arg.name, llvm_self_ptr)
          else
            raise "Bug: out argument was #{arg}"
          end
        else
          accept arg
          call_args << @last
        end
      end

      call_args
    end

    def codegen_call_with_block(node, block, owner, call_args, old_context)
      context.block = block
      context.block_context = old_context
      context.vars = {} of String => LLVMVar
      context.type = owner

      target_def = node.target_def

      if owner.passed_as_self?
        args_base_index = 1
        if owner.represented_as_union?
          ptr = alloca(llvm_type(owner))
          value = load call_args[0]
          store value, ptr
          context.vars["self"] = LLVMVar.new(ptr, owner)
        else
          context.vars["self"] = LLVMVar.new(call_args[0], owner, true)
        end
      else
        args_base_index = 0
      end

      target_def_vars = target_def.vars

      target_def.args.each_with_index do |arg, i|
        var_type = target_def_vars ? target_def_vars[arg.name].type : arg.type
        ptr = alloca(llvm_type(var_type), arg.name)
        context.vars[arg.name] = LLVMVar.new(ptr, var_type)
        value = call_args[args_base_index + i]
        assign(ptr, var_type, arg.type, value)
      end

      return_block = context.return_block = new_block "return"
      return_block_table = context.return_block_table = LLVM::PhiTable.new
      return_type = setup_context_return context, node.type

      accept target_def.body

      if target_def.no_returns? || target_def.body.no_returns? || target_def.body.returns?
        unreachable
      else
        unless block.breaks?
          codegen_return(target_def.body.type, target_def.type) do |ret_value|
            return_block_table.add insert_block, ret_value if ret_value
          end
        end
        br return_block
      end

      position_at_end return_block

      if node.no_returns? || node.returns? || block_returns? || ((node_block = node.block) && node_block.yields? && block_breaks?)
        unreachable
      else
        if node_type = node.type?
          if return_union = context.return_union
            @last = return_union
          elsif return_block_table.empty?
            @last = llvm_nil
          else
            phi_type = llvm_type(node_type)
            phi_type = pointer_type(phi_type) if node_type.represented_as_union?
            @last = phi phi_type, return_block_table
          end
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
        branch = new_branched_block(node)

        # Iterate all defs and check if any match the current types, given their ids (obj_type_id and arg_type_ids)
        target_defs.each do |a_def|
          result = match_type_id(owner, a_def.owner.not_nil!, obj_type_id)
          a_def.args.each_with_index do |arg, i|
            result = and(result, match_type_id(node.args[i].type, arg.type, arg_type_ids[i]))
          end

          current_def_label, next_def_label = new_blocks ["current_def", "next_def"]
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

          add_branched_block_value(branch, a_def.type, @last)
          position_at_end next_def_label
        end

        unreachable
        close_branched_block(branch)
      end
    end

    def type_id(value, type)
      case type
      when NilableType
        @builder.select null_pointer?(value), int(@mod.nil.type_id), int(type.not_nil_type.type_id)
      when UnionType, HierarchyType
        load(union_type_id(value))
      when HierarchyTypeMetaclass
        value
      else
        int(type.type_id)
      end
    end

    def match_type_id(type, restriction, type_id)
      case type
      when UnionType, HierarchyType, HierarchyTypeMetaclass
        match_any_type_id(restriction, type_id)
      when NilableType
        equal? int(restriction.type_id), type_id
      else
        llvm_true
      end
    end

    def setup_context_return(context, return_type)
      context.return_type = return_type
      if return_type.passed_by_value?
        context.return_union = alloca(llvm_type(return_type), "return")
      else
        context.return_union = nil
      end
      return_type
    end

    def codegen_call(node, self_type, call_args)
      target_def = node.target_def
      body = target_def.body

      if body.is_a?(Primitive)
        with_cloned_context do
          context.type = self_type
          codegen_primitive(body, target_def, call_args)
        end
        return
      end

      func = target_def_fun(target_def, self_type)

      codegen_call_or_invoke(func, call_args, target_def.raises, target_def.type)
    end

    def codegen_call_or_invoke(func, call_args, raises, type)
      if @exception_handlers.empty? || !raises
        @last = call func, call_args
      else
        handler = @exception_handlers.last
        invoke_out_block = new_block "invoke_out"
        @last = @builder.invoke func, call_args, invoke_out_block, handler.catch_block
        position_at_end invoke_out_block
      end

      if type.no_return?
        unreachable
      end

      if type.passed_by_value?
        union = alloca llvm_type(type)
        store @last, union
        @last = union
      end

      @last
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

    def codegen_fun(mangled_name, target_def, self_type, is_exported_fun_def = false, fun_module = type_module(self_type))
      if target_def.type.void?
        llvm_return_type = LLVM::Void
      else
        llvm_return_type = llvm_type(target_def.type)
      end

      old_position = insert_block
      old_entry_block = @entry_block
      old_alloca_block = @alloca_block
      old_exception_handlers = @exception_handlers
      old_in_const_block = @in_const_block
      old_llvm_mod = @llvm_mod

      with_cloned_context do
        context.type = self_type
        context.vars = {} of String => LLVMVar
        @llvm_mod = fun_module

        @in_const_block = false
        @trampoline_wrappers = {} of UInt64 => LLVM::Function

        @exception_handlers = [] of Handler

        args = [] of Arg
        if self_type.passed_as_self?
          args << Arg.new_with_type("self", self_type)
        end
        args.concat target_def.args

        if target_def.is_a?(External)
          is_external = true
          varargs = target_def.varargs
        end

        context.fun = @llvm_mod.functions.add(
          mangled_name,
          args.map { |arg| llvm_arg_type(arg.type) },
          llvm_return_type,
          varargs
        )
        context.fun.add_attribute LibLLVM::Attribute::NoReturn if target_def.no_returns?

        if @single_module && !is_external
          context.fun.linkage = LibLLVM::Linkage::Internal
        end

        args.each_with_index do |arg, i|
          param = context.fun.get_param(i)
          LLVM.set_name param, arg.name

          # Set 'byval' attribute
          if arg.type.passed_by_value?
            # but don't set it if it's the "self" argument and it's a struct
            unless i == 0 && self_type.struct?
              LLVM.add_attribute param, LibLLVM::Attribute::ByVal
            end
          end
        end

        if (!is_external && target_def.body) || is_exported_fun_def
          body = target_def.body
          new_entry_block

          target_def_vars = target_def.vars

          args.each_with_index do |arg, i|
            if (self_type.passed_as_self? && i == 0 && !self_type.represented_as_union?) || arg.type.passed_by_value?
              context.vars[arg.name] = LLVMVar.new(context.fun.get_param(i), arg.type, true)
            else
              var_type = target_def_vars ? target_def_vars[arg.name].type : arg.type
              pointer = alloca(llvm_type(var_type), arg.name)
              context.vars[arg.name] = LLVMVar.new(pointer, var_type)
              assign pointer, var_type, arg.type, context.fun.get_param(i)
            end
          end

          if body
            return_type = setup_context_return context, target_def.type
            accept body
            if body.returns?
              unreachable
            else
              codegen_return(target_def.body.type?, return_type) { |value| ret value }
            end
          end

          br_from_alloca_to_entry

          position_at_end old_position
        end

        @last = llvm_nil

        @llvm_mod = old_llvm_mod
        @exception_handlers = old_exception_handlers
        @entry_block = old_entry_block
        @alloca_block = old_alloca_block
        @in_const_block = old_in_const_block

        context.fun
      end
    end

    def match_any_type_id(type, type_id)
      # Special case: if the type is Object+ we want to match against Reference+,
      # because Object+ can only mean a Reference type (so we exclude Nil, for example).
      type = @mod.reference.hierarchy_type if type == @mod.object.hierarchy_type

      if type.represented_as_union? || type.hierarchy_metaclass?
        if type.is_a?(HierarchyType) && type.base_type.subclasses.empty?
          return equal? int(type.base_type.type_id), type_id
        end

        match_fun_name = "~match<#{type}>"
        func = @main_mod.functions[match_fun_name]? || create_match_fun(match_fun_name, type)
        func = check_main_fun match_fun_name, func
        return call func, [type_id] of LibLLVM::ValueRef
      end

      equal? int(type.type_id), type_id
    end

    def create_match_fun(name, type : UnionType | HierarchyType | HierarchyTypeMetaclass)
      @main_mod.functions.add(name, ([LLVM::Int32] of LibLLVM::TypeRef), LLVM::Int1) do |func|
        type_id = func.get_param(0)
        func.append_basic_block("entry") do |builder|
          result = nil
          type.each_concrete_type do |sub_type|
            sub_type_cond = builder.icmp(LibLLVM::IntPredicate::EQ, int(sub_type.type_id), type_id)
            result = result ? builder.or(result, sub_type_cond) : sub_type_cond
          end
          builder.ret result.not_nil!
        end
      end
    end

    def create_match_fun(name, type)
      raise "Bug: shouldn't create match fun for #{type}"
    end

    def type_module(type)
      return @main_mod if @single_module

      type = type.typedef if type.is_a?(TypeDefType)
      case type
      when Nil, Program
        type_name = ""
      else
        type_name = type.instance_type.to_s
      end

      llvm_mod = @modules[type_name]?
      unless llvm_mod
        llvm_mod = LLVM::Module.new(type_name)
        define_symbol_table llvm_mod
        @modules[type_name] = llvm_mod
      end
      llvm_mod
    end

    def new_entry_block
      @alloca_block, @entry_block = new_entry_block_chain ["alloca", "entry"]
    end

    def new_entry_block_chain names
      blocks = new_blocks names
      position_at_end blocks.last
      blocks
    end

    def br_from_alloca_to_entry
      br_block_chain [@alloca_block, @entry_block]
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

    def alloca(type, name = "")
      in_alloca_block { @builder.alloca type, name }
    end

    def in_alloca_block
      old_block = insert_block
      if @in_const_block
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
      old_in_const_block = @in_const_block
      old_llvm_mod = @llvm_mod
      old_exception_handlers = @exception_handlers

      with_cloned_context do
        context.fun = @main

        @exception_handlers = [] of Handler
        @in_const_block = true
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
      @in_const_block = old_in_const_block
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

    def to_lhs(ptr, type)
      type.passed_by_value? ? ptr : load ptr
    end

    def to_rhs(ptr, type)
      type.passed_by_value? ? load ptr : ptr
    end

    def to_nilable(ptr, to_type, from_type)
      from_type ||= @mod.nil
      from_type.nil_type? ? LLVM.null(llvm_type(to_type)) : ptr
    end

    def union_type_id_and_value(union_pointer)
      type_id_ptr = union_type_id(union_pointer)
      value_ptr = union_value(union_pointer)
      [type_id_ptr, value_ptr]
    end

    def union_type_id(union_pointer)
      aggregate_index union_pointer, 0
    end

    def union_value(union_pointer)
      aggregate_index union_pointer, 1
    end

    def aggregate_index(ptr, index)
      gep ptr, 0, index
    end


    def llvm_self(type = context.type)
      self_var = context.vars["self"]?
      if self_var
        self_var.pointer
      else
        int32(type.not_nil!.type_id)
      end
    end

    def llvm_self_ptr
      type = context.type
      if type.is_a?(HierarchyType)
        ptr = load(union_value(llvm_self))
        cast_to ptr, type.base_type
      else
        llvm_self
      end
    end

    def instance_var_ptr(type, name, pointer)
      index = type.index_of_instance_var(name)
      index += 1 unless type.struct?
      aggregate_index pointer, index
    end

    def build_string_constant(str, name = "str")
      name = name.replace '@', '.'
      key = StringKey.new(@llvm_mod, str)
      @strings[key] ||= begin
        global = @llvm_mod.globals.add(LLVM.struct_type([LLVM::Int32, LLVM::Int32, LLVM.array_type(LLVM::Int8, str.length + 1)]), name)
        LLVM.set_linkage global, LibLLVM::Linkage::Private
        LLVM.set_global_constant global, true
        LLVM.set_initializer global, LLVM.struct([int32(@mod.string.type_id), int32(str.length), LLVM.string(str)])
        cast_to global, @mod.string
      end
    end

    def accept(node)
      # old_current_node = @current_node
      node.accept self
      # @current_node = old_current_node
    end
  end
end
