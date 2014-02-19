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
      mod.symbols.to_a.each_with_index do |sym, index|
        @symbols[sym] = index
        @symbol_table_values << build_string_constant(sym, sym)
      end

      symbol_table = @llvm_mod.globals.add(LLVM.array_type(llvm_type(mod.string), @symbol_table_values.count), "symbol_table")
      LLVM.set_initializer symbol_table, LLVM.array(llvm_type(mod.string), @symbol_table_values)

      @last = llvm_nil
      @in_const_block = false
      @trampoline_wrappers = {} of UInt64 => LLVM::Function
      @fun_literal_count = 0
    end

    def type
      context.type.not_nil!
    end

    def finish
      br_block_chain [@alloca_block, @const_block_entry]
      br_block_chain [@const_block, @entry_block]
      val = return_from_fun nil, @main_ret_type unless @main_ret_type && @main_ret_type.no_return?
      if DUMP_LLVM
        @llvm_mod.dump
      end
      val
    end

    def visit(node : FunDef)
      unless node.external.dead
        codegen_fun node.real_name, node.external, nil, true
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
        p1 = t1.signed? ? @builder.sext(p1, llvm_type(t2)) : @builder.zext(p1, llvm_type(t2))
      else
        p2 = t2.signed? ? @builder.sext(p2, llvm_type(t1)) : @builder.zext(p2, llvm_type(t1))
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
      p1 = if t1.signed?
            @builder.si2fp(p1, llvm_type(t2))
           else
             @builder.ui2fp(p1, llvm_type(t2))
           end
      codegen_binary_op(op, t2, t2, p1, p2)
    end

    def codegen_binary_op(op, t1 : FloatType, t2 : IntegerType, p1, p2)
      p2 = if t2.signed?
            @builder.si2fp(p2, llvm_type(t1))
           else
             @builder.ui2fp(p2, llvm_type(t1))
           end
      codegen_binary_op op, t1, t1, p1, p2
    end

    def codegen_binary_op(op, t1 : FloatType, t2 : FloatType, p1, p2)
      if t1.rank < t2.rank
        p1 = @builder.fpext(p1, llvm_type(t2))
      elsif t1.rank > t2.rank
        p2 = @builder.fpext(p2, llvm_type(t1))
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

      if t1.rank < t2.rank
        @last = @builder.fptrunc(@last, llvm_type(t1))
      end

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
        from_type.signed? ? @builder.sext(arg, llvm_type(to_type)) : @builder.zext(arg, llvm_type(to_type))
      else
        trunc arg, llvm_type(to_type)
      end
    end

    def codegen_cast(from_type : IntegerType, to_type : FloatType, arg)
      if from_type.signed?
        @builder.si2fp arg, llvm_type(to_type)
      else
        @builder.ui2fp arg, llvm_type(to_type)
      end
    end

    def codegen_cast(from_type : FloatType, to_type : IntegerType, arg)
      if to_type.signed?
        @builder.fp2si arg, llvm_type(to_type)
      else
        @builder.fp2ui arg, llvm_type(to_type)
      end
    end

    def codegen_cast(from_type : FloatType, to_type : FloatType, arg)
      if from_type.rank < to_type.rank
        @builder.fpext arg, llvm_type(to_type)
      elsif from_type.rank > to_type.rank
        @builder.fptrunc arg, llvm_type(to_type)
      else
        arg
      end
    end

    def codegen_cast(from_type : IntegerType, to_type : CharType, arg)
      codegen_cast(from_type, @mod.int32, arg)
    end

    def codegen_cast(from_type : CharType, to_type : IntegerType, arg)
      @builder.zext(arg, llvm_type(to_type))
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

      struct_type = llvm_struct_type(base_type)

      if type.struct?
        @last = @builder.alloca struct_type
      else
        @last = malloc struct_type
      end

      memset @last, int8(0), size_of(struct_type)

      unless type.struct?
        type_id_ptr = gep @last, 0, 0
        store int32(base_type.type_id), type_id_ptr
      end

      if type.is_a?(HierarchyType)
        @last = box_object_in_hierarchy(base_type, type, @last, false)
      end

      @last
    end

    def codegen_primitive_pointer_malloc(node, target_def, call_args)
      type = node.type as PointerInstanceType
      llvm_type = llvm_embedded_type(type.var.type)
      array_malloc(llvm_type, call_args[1])
    end

    def codegen_primitive_pointer_set(node, target_def, call_args)
      type = context.type as PointerInstanceType
      value = call_args[1]
      codegen_assign call_args[0], type.var.type, node.type, value
      value
    end

    def codegen_primitive_pointer_get(node, target_def, call_args)
      type = context.type as PointerInstanceType
      @last = call_args[0]
      @last = load @last unless type.var.type.union? || type.var.type.struct_like?
      @last
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
      size = @builder.mul size, llvm_size(type.var.type)
      reallocated_ptr = realloc casted_ptr, size
      @last = cast_to_pointer reallocated_ptr, type.var.type
    end

    def codegen_primitive_pointer_add(node, target_def, call_args)
      @last = gep call_args[0], call_args[1]
    end

    def codegen_primitive_byte_size(node, target_def, call_args)
      llvm_size(type.instance_type)
    end

    def codegen_primitive_struct_new(node, target_def, call_args)
      type = node.type as PointerInstanceType

      struct_type = type.var.type as CStructType

      llvm_struct_type = llvm_struct_type(struct_type)
      @last = malloc llvm_struct_type
      memset @last, int8(0), size_of(llvm_struct_type)
      @last
    end

    def codegen_primitive_struct_set(node, target_def, call_args)
      type = context.type as CStructType

      name = target_def.name[0 .. -2]

      @last = call_args[1]

      value = @last
      value = load value if node.type.struct_like?

      ptr = struct_field_ptr(type, name, call_args[0])
      store value, ptr

      call_args[1]
    end

    def codegen_primitive_struct_get(node, target_def, call_args)
      type = context.type as CStructType

      name = target_def.name

      @last = struct_field_ptr(type, name, call_args[0])
      @last = load @last unless node.type.struct_like?
      @last
    end

    def struct_field_ptr(type, field_name, pointer)
      index = type.index_of_var(field_name)
      gep pointer, 0, index
    end

    def codegen_primitive_union_new(node, target_def, call_args)
      type = node.type as PointerInstanceType

      union_type = type.var.type as CUnionType

      llvm_union_type = llvm_struct_type(union_type)
      @last = malloc llvm_union_type
      memset @last, int8(0), size_of(llvm_union_type)
      @last
    end

    def codegen_primitive_union_set(node, target_def, call_args)
      type = context.type as CUnionType

      name = target_def.name[0 .. -2]

      @last = call_args[1]
      @last = load @last if node.type.struct_like?

      ptr = union_field_ptr(node, call_args[0])
      store @last, ptr
      @last
    end

    def codegen_primitive_union_get(node, target_def, call_args)
      type = context.type as CUnionType

      name = target_def.name

      @last = union_field_ptr(node, call_args[0])
      @last = load @last unless node.type.struct_like?
      @last
    end

    def union_field_ptr(node, pointer)
      ptr = gep pointer, 0, 0
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
      obj = load(gep obj, 0, 1) if type.hierarchy?
      ptr2int obj, LLVM::Int64
    end

    def codegen_primitive_object_to_cstr(node, target_def, call_args)
      obj = call_args[0]
      obj = load(gep obj, 0, 1) if type.hierarchy?
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
        type_ptr = union_type_id call_args[0]
        load type_ptr
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

    def visit(node : PointerOf)
      node_exp = node.exp
      case node_exp
      when Var
        @last = context.vars[node_exp.name].pointer
      when InstanceVar
        @last = instance_var_ptr (context.type as InstanceVarContainer), node_exp.name, llvm_self_ptr
      when IndirectRead
        @last = visit_indirect(node_exp)
      else
        raise "Bug: pointerof(#{node})"
      end
      false
    end

    def visit(node : SimpleOr)
      node.left.accept self
      left = codegen_cond(node.left.type)

      node.right.accept self
      right = codegen_cond(node.right.type)

      @last = or left, right
      false
    end

    def visit(node : ASTNode)
      true
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

    def visit(node : BoolLiteral)
      @last = int1(node.value ? 1 : 0)
    end

    def visit(node : LongLiteral)
      @last = int64(node.value.to_i)
    end

    def visit(node : CharLiteral)
      @last = int32(node.value.ord)
    end

    def visit(node : StringLiteral)
      @last = build_string_constant(node.value)
    end

    def visit(node : SymbolLiteral)
      @last = int(@symbols[node.value])
    end

    def visit(node : FunLiteral)
      @fun_literal_count += 1

      fun_literal_name = "~fun_literal_#{@fun_literal_count}"
      the_fun = codegen_fun(fun_literal_name, node.def, nil, false, @main_mod)
      @last = the_fun.fun
      @last = (check_main_fun fun_literal_name, the_fun).fun

      false
    end

    def visit(node : FunPointer)
      owner = node.call.target_def.owner.not_nil!
      owner = nil unless owner.passed_as_self?
      if obj = node.obj
        accept(obj)
        call_self = @last
      elsif owner
        call_self = llvm_self
      end
      last_fun = target_def_fun(node.call.target_def, owner)
      @last = last_fun.fun

      if owner && call_self
        wrapper = trampoline_wrapper(node.call.target_def, last_fun)
        tramp_ptr = array_malloc(LLVM::Int8, int(32))
        call @mod.trampoline_init(@llvm_mod), [
          tramp_ptr,
          bit_cast(wrapper.fun, pointer_type(LLVM::Int8)),
          bit_cast(call_self, pointer_type(LLVM::Int8))
        ]
        @last = call @mod.trampoline_adjust(@llvm_mod), [tramp_ptr]
        @last = cast_to(@last, node.type)
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
            if target_def.no_returns?
              builder.unreachable
            elsif target_def.type.void?
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

    def visit(node : Nop)
      @last = llvm_nil
    end

    def visit(node : NilLiteral)
      @last = llvm_nil
    end

    def visit(node : Expressions)
      node.expressions.each do |exp|
        accept(exp)
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
            accept(node_ensure)
          end
          @last = old_last
        end
      end

      return_type = context.return_type.not_nil!

      if return_block = context.return_block
        if return_type.union?
          @last = assign_to_return_union(return_type, node.exps[0].type, @last)
        end
        context.return_block_table.not_nil!.add(insert_block, @last)
        br return_block
      elsif return_type.union?
        ret assign_to_return_union(return_type, node.exps[0].type, @last)
      elsif return_type.nilable?
        if LLVM.type_kind_of(type_of @last) == LibLLVM::TypeKind::Integer
          ret int2ptr(@last, llvm_type(return_type))
        else
          ret @last
        end
      else
        @last = load @last if return_type.struct_like?
        ret @last
      end
    end

    def assign_to_return_union(return_type, value_type, value)
      return_union = return_union()
      assign_to_union(return_union, return_type, value_type, value)
      load return_union
    end

    def return_union
      context.return_union.not_nil!
    end

    def visit(node : ClassDef)
      node.body.accept self
      @last = llvm_nil
      false
    end

    def visit(node : ModuleDef)
      node.body.accept self
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

    def cast_to(value, type)
      bit_cast(value, llvm_type(type))
    end

    def cast_to_pointer(value, type)
      bit_cast(value, pointer_type(llvm_type(type)))
    end

    def cast_to_void_pointer(pointer)
      bit_cast pointer, pointer_type(LLVM::Int8)
    end

    def visit(node : If)
      accept(node.cond)

      then_block, else_block = new_blocks ["then", "else"]
      codegen_cond_branch(node.cond, then_block, else_block)

      branch = new_branched_block(node)

      position_at_end then_block
      accept(node.then)
      add_branched_block_value(branch, node.then.type?, @last)
      br branch.exit_block

      position_at_end else_block
      accept(node.else)
      add_branched_block_value(branch, node.else.type?, @last)
      br branch.exit_block

      close_branched_block(branch)

      false
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

        accept(node.cond)
        codegen_cond_branch(node.cond, body_block, exit_block)

        position_at_end body_block
        accept(node.body)
        br while_block

        position_at_end exit_block
        unreachable if node.no_returns? || (node.body.yields? && block_breaks?)

        @last = llvm_nil
      end

      false
    end

    def codegen_cond_branch(node_cond, then_block, else_block)
      cond(codegen_cond(node_cond.type), then_block, else_block)

      nil
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

    def end_visit(node : Break)
      break_type = context.break_type
      break_table = context.break_table

      if break_type && break_type.union?
        break_union = context.break_union.not_nil!

        if node.exps.length > 0
          assign_to_union(break_union, break_type, node.exps[0].type, @last)
        else
          assign_to_union(break_union, break_type, @mod.nil, llvm_nil)
        end
      elsif break_table
        if break_type && break_type.nilable? && node.exps.empty?
          break_table.add insert_block, int2ptr(llvm_nil, llvm_type(break_type))
        else
          break_table.add insert_block, @last
        end
      end

      br context.while_exit_block.not_nil!
    end

    def end_visit(node : Next)
      if while_block = context.while_block
        br while_block
      end
    end

    def block_returns?
      return false unless context.block? && context.block_context?
      context.block.returns? || (context.block.yields? && with_context(context.block_context) { block_returns? })
    end

    def block_breaks?
      return false unless context.block? && context.block_context?
      context.block.breaks? || (context.block.yields? && with_context(context.block_context) { block_breaks? })
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
        @codegen.codegen_assign(@union_ptr, @node.type, type, value)
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
        if @node.type.nilable? && LLVM.type_kind_of(type_of value) == LibLLVM::TypeKind::Integer
          @phi_table.add block, int2ptr(value, @codegen.llvm_type(node.type))
        else
          value = load value if type.struct_like?
          @phi_table.add block, value
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
      node_type = node.type?
      if node_type && (node_type.union? || node_type.struct_like?)
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
      codegen_assign_node(node.target, node.value)
    end

    def codegen_assign_node(target, value)
      if target.is_a?(Path)
        @last = llvm_nil
        return false
      end

      accept(value)

      if value.no_returns? || value.returns? || value.breaks? || (value.yields? && (block_returns? || block_breaks?))
        return
      end

      codegen_assign_target(target, value, @last) if @last

      false
    end

    def codegen_assign_target(target : InstanceVar, value, llvm_value)
      ptr = instance_var_ptr (context.type as InstanceVarContainer), target.name, llvm_self_ptr
      codegen_assign(ptr, target.type, value.type, llvm_value)
    end

    def codegen_assign_target(target : Global, value, llvm_value)
      ptr = get_global target.name, target.type
      codegen_assign(ptr, target.type, value.type, llvm_value)
    end

    def codegen_assign_target(target : ClassVar, value, llvm_value)
      ptr = get_global class_var_global_name(target), target.type
      codegen_assign(ptr, target.type, value.type, llvm_value)
    end

    def codegen_assign_target(target : Var, value, llvm_value)
      if target.type == @mod.void
        context.vars[target.name] = LLVMVar.new(llvm_nil, @mod.void)
        return
      end

      var = declare_var(target)
      ptr = var.pointer
      codegen_assign(ptr, target.type, value.type, llvm_value)
    end

    def codegen_assign_target(target, value, llvm_value)
      raise "Unknown assign target in codegen: #{target}"
    end

    def get_global(name, type)
      ptr = @llvm_mod.globals[name]?
      unless ptr
        llvm_type = llvm_type(type)
        if @llvm_mod == @main_mod
          ptr = @llvm_mod.globals.add(llvm_type, name)
          LLVM.set_initializer ptr, LLVM.null(llvm_type)
        else
          ptr = @llvm_mod.globals.add(llvm_type, name)
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

    def codegen_assign(pointer, target_type, value_type, value, load_struct_and_union = true)
      if target_type == value_type
        value = load value if target_type.union? || (load_struct_and_union && target_type.struct_like?)
        store value, pointer
      elsif target_type.is_a?(HierarchyTypeMetaclass) && value_type.is_a?(Metaclass)
        store value, pointer
      # Hack until we fix it in the type inference
      elsif value_type.is_a?(HierarchyType) && value_type.base_type == target_type
        union_ptr = union_value value
        union_ptr = cast_to_pointer union_ptr, target_type
        union = load(union_ptr)
        store union, pointer
      else
        assign_to_union(pointer, target_type, value_type, value)
      end
    end

    def cast_number(target_type : IntegerType, value_type : IntegerType, value)
      if target_type.normal_rank != value_type.normal_rank
        if target_type.unsigned? && value_type.unsigned?
          value = @builder.zext(value, llvm_type(target_type))
        else
          value = @builder.sext(value, llvm_type(target_type))
        end
      end
      value
    end

    def cast_number(target_type : FloatType, value_type : IntegerType, value)
      if value_type.unsigned?
        @builder.ui2fp(value, llvm_type(target_type))
      else
        @builder.si2fp(value, llvm_type(target_type))
      end
    end

    def cast_number(target_type, value_type, value)
      raise "Bug: called cast_number with types #{target_type} <- #{value_type}"
    end

    def assign_to_union(union_pointer, union_type : NilableType, type, value)
      if LLVM.type_kind_of(type_of value) == LibLLVM::TypeKind::Integer
        value = int2ptr value, llvm_type(union_type)
      end
      store value, union_pointer
    end

    def assign_to_union(union_pointer, union_type, type, value)
      if type.union?
        casted_value = cast_to_pointer value, union_type
        store load(casted_value), union_pointer
      elsif type.is_a?(NilableType)
        type_id_ptr, value_ptr = union_type_id_and_value(union_pointer)

        index = @builder.select null_pointer?(value), int(@mod.nil.type_id), int(type.not_nil_type.type_id)

        store index, type_id_ptr

        casted_value_ptr = cast_to_pointer value_ptr, type.not_nil_type
        store value, casted_value_ptr
      else
        type_id_ptr, value_ptr = union_type_id_and_value(union_pointer)

        index = type.type_id
        store int32(index), type_id_ptr

        unless type == @mod.void
          casted_value_ptr = cast_to_pointer value_ptr, type
          value = load value if type.struct_like?
          store value, casted_value_ptr
        end
      end
    end

    def union_type_id_and_value(union_pointer)
      type_id_ptr = union_type_id(union_pointer)
      value_ptr = union_value(union_pointer)
      [type_id_ptr, value_ptr]
    end

    def union_type_id(union_pointer)
      gep union_pointer, 0, 0
    end

    def union_value(union_pointer)
      gep union_pointer, 0, 1
    end

    def visit(node : Var)
      var = context.vars[node.name]
      var_type = var.type
      @last = var.pointer
      if var_type == @mod.void
        # Nothing to do
      elsif var_type == node.type
        @last = load @last unless var.treated_as_pointer || var_type.union? || var_type.struct_like?
      elsif var_type.is_a?(NilableType)
        if node.type.nil_type?
          @last = null_pointer?(@last)
        else
          @last = load @last unless var.treated_as_pointer
        end
      elsif node.type.union?
        @last = cast_to_pointer @last, node.type
      else
        value_ptr = union_value(@last)
        @last = cast_to_pointer value_ptr, node.type
        @last = load @last unless node.type.passed_by_val?
      end
    end

    def visit(node : CastedVar)
      var = context.vars[node.name]
      cast_value var.pointer, node.type, var.type, var.treated_as_pointer
    end

    def cast_value(value, to_type, from_type, treated_as_pointer = false)
      @last = value
      if from_type == @mod.void
        # Nothing to do
      elsif from_type == to_type
        @last = load @last unless (treated_as_pointer || from_type.union?)
      elsif from_type.is_a?(NilableType)
        if to_type.nil_type?
          @last = llvm_nil
        elsif to_type == @mod.object
          @last = cast_to @last, @mod.object
        elsif to_type == @mod.object.hierarchy_type
          @last = box_object_in_hierarchy(from_type, to_type, @last, !treated_as_pointer)
        else
          @last = load @last unless treated_as_pointer
          if to_type.hierarchy?
            @last = box_object_in_hierarchy(from_type.not_nil_type, to_type, @last, !treated_as_pointer)
          end
        end
      elsif from_type.metaclass?
        # Nothing to do
      elsif to_type.union?
        @last = cast_to_pointer @last, to_type
      else
        value_ptr = union_value(@last)
        @last = cast_to_pointer value_ptr, to_type
        @last = load @last unless to_type.struct_like?
      end
    end

    def box_object_in_hierarchy(object, hierarchy, value, load = true)
      hierarchy_type = alloca llvm_type(hierarchy)
      type_id_ptr, value_ptr = union_type_id_and_value(hierarchy_type)
      if object.is_a?(NilableType)
        null_pointer = null_pointer?(value)
        value_id = @builder.select null_pointer?(value), int(@mod.nil.type_id), int(object.not_nil_type.type_id)
      else
        value_id = int(object.type_id)
      end

      store value_id, type_id_ptr

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
      @last = load @last unless type.union? || type.struct_like?
      @last
    end

    def visit(node : InstanceVar)
      type = context.type as InstanceVarContainer

      ivar = type.lookup_instance_var(node.name)
      @last = instance_var_ptr type, node.name, llvm_self_ptr

      if ivar.type.union? || ivar.type.struct_like?
        unless node.type == ivar.type
          if node.type.union?
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
      node.obj.accept self
      last_value = @last

      obj_type = node.obj.type
      to_type = node.to.type.instance_type

      if obj_type.pointer?
        resulting_type = to_type
      else
        resulting_type = obj_type.filter_by(to_type).not_nil!
      end

      if obj_type.pointer?
        @last = cast_to last_value, resulting_type
      elsif obj_type.union?
        type_id_ptr = union_type_id last_value
        type_id = load type_id_ptr

        cmp = match_any_type_id resulting_type, type_id

        matches_block, doesnt_match_block = new_blocks ["matches", "doesnt_match"]
        cond cmp, matches_block, doesnt_match_block

        position_at_end doesnt_match_block
        type_cast_exception_call.accept self

        position_at_end matches_block
        cast_value last_value, resulting_type, obj_type
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
      accept(node.obj)

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
      context.vars[var.name] ||= begin
        llvm_var = LLVMVar.new(alloca(llvm_type(var.type), var.name), var.type)
        var_type = var.type
        if var_type.is_a?(UnionType) && var_type.union_types.any?(&.nil_type?)
          in_alloca_block { assign_to_union(llvm_var.pointer, var.type, @mod.nil, llvm_nil) }
        end
        llvm_var
      end
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

    def declare_out_arguments(call)
      call.target_def.args.each_with_index do |arg, i|
        var = call.args[i]
        if var.out? && var.is_a?(Var)
          declare_var(var)
        end
      end
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
              accept(const.not_nil!.value)

              if LLVM.constant? @last
                LLVM.set_initializer global, @last
                LLVM.set_global_constant global, true
              else
                if const.value.type.struct_like?
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
            accept(const.value)
            LLVM.set_initializer global, @last
            LLVM.set_global_constant global, true
            @llvm_mod = old_llvm_mod
          end
        end

        if @llvm_mod != @main_mod
          global = @llvm_mod.globals[global_name]?
          global ||= @llvm_mod.globals.add(llvm_type(const.value.type), global_name)
        end

        @last = global
        @last = load @last unless const.value.type.struct_like?
      elsif replacement = node.syntax_replacement
        replacement.accept self
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
      old_context = @context
      @context = new_context.clone
      value = yield old_context
      @context = old_context
      value
    end

    def with_context(new_context)
      old_context = @context
      @context = new_context
      value = yield old_context
      @context = old_context
      value
    end

    def visit(node : Yield)
      if block_context = context.block_context?
        new_vars = block_context.vars.dup
        block = context.block

        if node_scope = node.scope
          node_scope.accept self
          new_vars["%scope"] = LLVMVar.new(@last, node_scope.type)
        end

        # First accept all yield expressions
        node.exps.each_with_index do |exp, i|
          exp.accept self

          arg = block.args[i]?
          if arg
            copy = alloca llvm_type(arg.type), "block_#{arg.name}"
            codegen_assign copy, arg.type, exp.type, @last
            new_vars[arg.name] = LLVMVar.new(copy, arg.type)
          end
        end

        # Then assign nil to remaining block args
        node.exps.length.upto(block.args.length - 1) do |i|
          arg = block.args[i]
          @last = llvm_nil

          copy = alloca llvm_type(arg.type), "block_#{arg.name}"
          codegen_assign copy, arg.type, @mod.nil, @last
          new_vars[arg.name] = LLVMVar.new(copy, arg.type)
        end

        with_cloned_context(block_context) do |old|
          context.vars = new_vars
          context.break_table = old.return_block_table
          context.break_type = old.return_type
          context.break_union = old.return_union
          context.while_exit_block = old.return_block
          accept(block)
        end

        if !node.type? || node.type.nil_type?
          @last = llvm_nil
        end
      end
      false
    end

    def visit(node : ExceptionHandler)
      catch_block = new_block "catch"
      branch = new_branched_block(node)

      @exception_handlers << Handler.new(node, catch_block, context.vars)
      accept(node.body)
      @exception_handlers.pop

      if node_else = node.else
        accept(node_else)
        add_branched_block_value(branch, node_else.type, @last)
      else
        add_branched_block_value(branch, node.body.type, @last)
      end

      br branch.exit_block

      position_at_end catch_block
      lp_ret_type = @llvm_typer.landing_pad_type
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

            accept(a_rescue.body)
          end
          add_branched_block_value(branch, a_rescue.body.type, @last)
          br branch.exit_block

          position_at_end next_rescue_block
        end
      end

      if node_ensure = node.ensure
        accept(node_ensure)
      end

      raise_fun = main_fun(RAISE_NAME)
      codegen_call_or_invoke(raise_fun, [bit_cast(unwind_ex_obj, type_of(raise_fun.get_param(0)))], true, @mod.no_return)

      close_branched_block(branch)
      if node_ensure
        old_last = @last
        accept(node_ensure)
        @last = old_last
      end

      false
    end

    def visit(node : IndirectRead)
      ptr = visit_indirect(node)
      ptr = cast_to_pointer ptr, node.type

      if node.type.struct_like?
        @last = ptr
      else
        @last = load ptr
      end

      false
    end

    def visit(node : IndirectWrite)
      ptr = visit_indirect(node)
      ptr = cast_to_pointer ptr, node.value.type

      node.value.accept self

      if node.value.type.struct_like?
        @last = load @last
      end

      store @last, ptr

      false
    end

    def visit_indirect(node)
      indices = [int32(0)]

      type = node.obj.type as PointerInstanceType

      element_type = type.var.type

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

      node.obj.accept self

      @builder.gep @last, indices
    end

    def visit(node : Call)
      if target_macro = node.target_macro
        accept(target_macro)
        return false
      end

      target_defs = node.target_defs

      if target_defs
        if target_defs.length > 1
          codegen_dispatch(node, target_defs)
          return false
        end

        if node.target_def.is_a?(External)
          declare_out_arguments(node)
        end
      end

      if !node.target_defs || node.target_def.owner.try &.is_subclass_of?(@mod.value)
        if node_obj = node.obj
          owner = node_obj.type?
        end
        owner ||= node.scope
      elsif node.name == "super"
        owner = node.scope
      else
        owner = node.target_def.owner
      end

      if owner && !owner.passed_as_self?
        owner = nil
      end

      call_args = [] of LibLLVM::ValueRef

      if (obj = node.obj) && obj.type.passed_as_self?
        accept(obj)
        call_args << @last
      elsif owner
        if yield_scope = context.vars["%scope"]?
          call_args << yield_scope.pointer
        else
          call_args << llvm_self(owner)
        end
      end

      node.args.each_with_index do |arg, i|
        if arg.out?
          case arg
          when Var
            call_args << context.vars[arg.name].pointer
          when InstanceVar
            call_args << instance_var_ptr(type, arg.name, llvm_self_ptr)
          else
            raise "Bug: out argument was #{arg}"
          end
        else
          accept(arg)
          call_args << @last
        end
      end

      return if node.args.any?(&.yields?) && block_breaks?

      if block = node.block
        with_cloned_context do |old|
          context.block = block
          context.block_context = old
          context.vars = {} of String => LLVMVar
          if owner
            context.type = owner
            args_base_index = 1
            if owner.union?
              ptr = alloca(llvm_type(owner))
              value = call_args[0]
              value = load(value) if owner.passed_by_val?
              store value, ptr
              context.vars["self"] = LLVMVar.new(ptr, owner)
            else
              context.vars["self"] = LLVMVar.new(call_args[0], owner, true)
            end
          else
            args_base_index = 0
          end

          target_def_vars = node.target_def.vars

          node.target_def.args.each_with_index do |arg, i|
            var_type = target_def_vars ? target_def_vars[arg.name].type : arg.type
            ptr = alloca(llvm_type(var_type), arg.name)
            context.vars[arg.name] = LLVMVar.new(ptr, var_type)
            value = call_args[args_base_index + i]
            codegen_assign(ptr, var_type, arg.type, value)
          end

          return_block = context.return_block = new_block "return"
          return_block_table = context.return_block_table = LLVM::PhiTable.new
          return_type = context.return_type = node.type
          if return_type.union? || return_type.struct_like?
            context.return_union = alloca(llvm_type(node.type), "return")
          else
            context.return_union = nil
          end

          accept(node.target_def.body)

          if node.target_def.no_returns? || node.target_def.body.no_returns? || node.target_def.body.returns?
            unreachable
          else
            node_target_def_type = node.target_def.type?
            node_target_def_body = node.target_def.body
            if node_target_def_type && !node_target_def_type.nil_type? && !block.breaks?
              if return_union = context.return_union
                if node_target_def_body && node_target_def_body.type?
                  codegen_assign(return_union, return_type, node_target_def_body.type, @last)
                else
                  unreachable
                end
              elsif node_target_def_type.is_a?(NilableType) && node_target_def_body && node_target_def_body.type? && node_target_def_body.type.nil_type?
                return_block_table.add insert_block, LLVM.null(llvm_type(node_target_def_type.not_nil_type))
              elsif return_type.void?
                # Nothing to do
              else
                value = @last
                return_block_table.add insert_block, value
              end
            elsif (!node_target_def_type || (node_target_def_type && node_target_def_type.nil_type?)) && node.type.nilable?
              return_block_table.add insert_block, int2ptr(llvm_nil, llvm_type(node.type))
            end
            br return_block
          end

          position_at_end return_block

          if node.no_returns? || node.returns? || block_returns? || ((node_block = node.block) && node_block.yields? && block_breaks?)
            unreachable
          else
            node_type = node.type?
            if node_type && !node_type.nil_type?
              if return_union = context.return_union
                @last = return_union
              elsif return_block_table.empty?
                @last = llvm_nil
              else
                phi_type = llvm_type(node_type)
                phi_type = pointer_type(phi_type) if node_type.union?
                @last = phi phi_type, return_block_table
              end
            end
          end
        end
      else
        with_cloned_context do
          context.return_block = nil
          context.return_block_table = nil
          context.break_table = nil
          codegen_call(node, owner, call_args)
        end
      end

      false
    end

    def codegen_dispatch(node, target_defs)
      branch = new_branched_block(node)

      if node_obj = node.obj
        owner = node_obj.type
        node_obj.accept(self)

        if owner.union?
          obj_type_id = load union_type_id(@last)
        elsif owner.nilable? || owner.hierarchy_metaclass?
          obj_type_id = @last
        end
      else
        owner = node.scope

        if owner == @mod.program
          # Nothing
        elsif owner.union?
          obj_type_id = load union_type_id(llvm_self)
        else
          obj_type_id = llvm_self
        end
      end

      call = Call.new(node_obj ? CastedVar.new("%self") : nil, node.name, Array(ASTNode).new(node.args.length) { |i| CastedVar.new("%arg#{i}") }, node.block)
      call.scope = node.scope

      new_vars = context.vars.dup

      if node_obj && node_obj.type.passed_as_self?
        new_vars["%self"] = LLVMVar.new(@last, node_obj.type, true)
      end

      arg_type_ids = [] of LibLLVM::ValueRef?
      node.args.each_with_index do |arg, i|
        arg.accept self
        if arg.type.union?
          arg_type_ids.push load(union_type_id(@last))
        elsif arg.type.nilable?
          arg_type_ids.push @last
        else
          arg_type_ids.push nil
        end
        new_vars["%arg#{i}"] = LLVMVar.new(@last, arg.type, true)
      end

      with_cloned_context do
        context.vars = new_vars

        next_def_label = nil
        target_defs.each do |a_def|
          if owner.union?
            result = match_any_type_id(a_def.owner.not_nil!, obj_type_id.not_nil!)
          elsif owner.nilable?
            if a_def.owner.not_nil!.nil_type?
              result = null_pointer?(obj_type_id.not_nil!)
            else
              result = not_null_pointer?(obj_type_id.not_nil!)
            end
          elsif owner.hierarchy_metaclass?
            result = match_any_type_id(a_def.owner.not_nil!, obj_type_id.not_nil!)
          else
            result = llvm_true
          end

          a_def.args.each_with_index do |arg, i|
            if node.args[i].type.union?
              comp = match_any_type_id(arg.type, arg_type_ids[i].not_nil!)
              result = and(result, comp)
            elsif node.args[i].type.nilable?
              if arg.type.nil_type?
                result = and(result, null_pointer?(arg_type_ids[i].not_nil!))
              else
                result = and(result, not_null_pointer?(arg_type_ids[i].not_nil!))
              end
            end
          end

          current_def_label, next_def_label = new_blocks ["current_def", "next_def"]
          cond result, current_def_label, next_def_label

          position_at_end current_def_label

          if call_obj = call.obj
            call_obj.set_type(a_def.owner)
          end

          call.target_defs = [a_def] of Def
          call.args.zip(a_def.args) do |call_arg, a_def_arg|
            call_arg.set_type(a_def_arg.type)
          end
          if (node_block = node.block) && node_block.break.type?
            call.set_type(@mod.type_merge [a_def.type, node_block.break.type] of Type)
          else
            call.set_type(a_def.type)
          end
          call.accept self

          add_branched_block_value(branch, a_def.type, @last)
          position_at_end next_def_label
        end

        unreachable
        close_branched_block(branch)
      end
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

      if type.union? || type.struct_like?
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
      if target_def.type == @mod.void
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
        context.vars = {} of String => LLVMVar
        @llvm_mod = fun_module

        @in_const_block = false
        @trampoline_wrappers = {} of UInt64 => LLVM::Function

        @exception_handlers = [] of Handler

        args = [] of Arg
        if self_type
          context.type = self_type
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
          if arg.type.passed_by_val?
            # but don't set it if it's the "self" argument and it's a struct
            unless i == 0 && self_type.try &.struct?
              LLVM.add_attribute param, LibLLVM::Attribute::ByVal
            end
          end
        end

        if (!is_external && target_def.body) || is_exported_fun_def
          body = target_def.body
          new_entry_block

          target_def_vars = target_def.vars

          args.each_with_index do |arg, i|
            if (self_type && i == 0 && !self_type.union?) || arg.type.passed_by_val?
              context.vars[arg.name] = LLVMVar.new(context.fun.get_param(i), arg.type, true)
            else
              var_type = target_def_vars ? target_def_vars[arg.name].type : arg.type
              pointer = alloca(llvm_type(var_type), arg.name)
              context.vars[arg.name] = LLVMVar.new(pointer, var_type)
              codegen_assign(pointer, var_type, arg.type, context.fun.get_param(i), false)
            end
          end

          if body
            return_type = context.return_type = target_def.type
            context.return_union = alloca(llvm_type(return_type), "return") if return_type.union?

            accept body

            return_from_fun target_def, return_type
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

    def return_from_fun(target_def, return_type)
      if target_def && target_def.type == @mod.void
        ret
      elsif target_def && target_def.body.no_returns?
        unreachable
      else
        if return_type.union?
          if target_def && target_def.body.type? != return_type && !target_def.body.returns?
            return_union = return_union()
            assign_to_union(return_union, return_type, target_def.body.type, @last)
            @last = load return_union
          else
            @last = load @last
          end
        end

        if return_type.is_a?(NilableType)
          if target_def
            if (target_def_body_type = target_def.body.type?) && target_def_body_type.nil_type?
              return ret LLVM.null(llvm_type(return_type))
            end
          end
        end

        if return_type == @mod.void
          ret
        elsif return_type.struct_like?
          ret(load @last)
        else
          ret(@last)
        end
      end
    end

    def match_any_type_id(type, type_id)
      # Special case: if the type is Object+ we want to match against Reference+,
      # because Object+ can only mean a Reference type (so we exclude Nil, for example).
      type = @mod.reference.hierarchy_type if type == @mod.object.hierarchy_type

      if type.union? || type.hierarchy_metaclass?
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
      type_name = (type ? type.instance_type : nil).to_s

      llvm_mod = @modules[type_name]?
      unless llvm_mod
        llvm_mod = LLVM::Module.new(type_name)
        llvm_mod.globals.add(LLVM.array_type(llvm_type(@mod.string), @symbol_table_values.count), "symbol_table")
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

    def llvm_type(type)
      @llvm_typer.llvm_type(type)
    end

    def llvm_struct_type(type)
      @llvm_typer.llvm_struct_type(type)
    end

    def llvm_arg_type(type)
      @llvm_typer.llvm_arg_type(type)
    end

    def llvm_embedded_type(type)
      @llvm_typer.llvm_embedded_type(type)
    end

    def llvm_size(type)
      size_of llvm_type(type)
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
      gep pointer, 0, index
    end

    def accept(node)
      # old_current_node = @current_node
      node.accept self
      # @current_node = old_current_node
    end
  end
end
