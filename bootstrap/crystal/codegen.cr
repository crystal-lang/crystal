require "parser"
require "type_inference"
require "visitor"
require "llvm"
require "codegen/*"

LLVM.init_x86

module Crystal
  DUMP_LLVM = ENV["DUMP"] == "1"

  def run(code)
    node = Parser.parse(code)
    mod = infer_type node
    evaluate node, mod
  end

  def evaluate(node, mod)
    llvm_mod = build node, mod
    engine = LLVM::JITCompiler.new(llvm_mod)
    engine.run_function llvm_mod.functions["crystal_main"] #, 0, nil
  end

  def build(node, mod)
    visitor = CodeGenVisitor.new(mod, node)
    node.accept visitor
    visitor.finish
    visitor.llvm_mod.dump if Crystal::DUMP_LLVM
    visitor.llvm_mod
  end

  class LLVMVar
    property :pointer
    property :type

    def initialize(@pointer, @type)
    end
  end

  class CodeGenVisitor < Visitor
    getter :llvm_mod
    getter :fun

    def initialize(@mod, @node)
      @llvm_mod = LLVM::Module.new("Crystal")
      @llvm_typer = LLVMTyper.new
      if node_type = node.type
        ret_type = @llvm_typer.llvm_type(node_type)
      else
        ret_type = LLVM::Void
      end
      @fun = @llvm_mod.functions.add("crystal_main", [] of LLVM::Type, ret_type)
      @builder = LLVM::Builder.new
      @alloca_block, @const_block, @entry_block = new_entry_block_chain ["alloca", "const", "entry"]
      @const_block_entry = @const_block
      @vars = {} of String => LLVMVar
      @strings = {} of String => LibLLVM::ValueRef
    end

    def finish
      br_block_chain [@alloca_block, @const_block_entry]
      br_block_chain [@const_block, @entry_block]
      last = @last
      last.is_a?(LibLLVM::ValueRef) ? @builder.ret(last) : @builder.ret

      @fun = @llvm_mod.functions.add "main", [] of LLVM::Type, LLVM::Int32
      entry = new_block "entry"
      @builder.position_at_end entry
      @builder.call @llvm_mod.functions["crystal_main"]
      @builder.ret LLVM::Int32.from_i(0)
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : NumberLiteral)
      case node.kind
      when :i8, :u8
        @last = LLVM::Int8.from_i(node.value.to_i)
      when :i16, :u16
        @last = LLVM::Int16.from_i(node.value.to_i)
      when :i32, :u32
        @last = LLVM::Int32.from_i(node.value.to_i)
      when :i64, :u64
        @last = LLVM::Int32.from_i(node.value.to_i64)
      when :f32
        @last = LLVM::Float.from_s(node.value)
      when :f64
        @last = LLVM::Double.from_s(node.value)
      end
    end

    def visit(node : BoolLiteral)
      @last = LLVM::Int1.from_i(node.value ? 1 : 0)
    end

    def visit(node : LongLiteral)
      @last = LLVM::Int64.from_i(node.value.to_i)
    end

    def visit(node : CharLiteral)
      @last = LLVM::Int8.from_i(node.value[0].ord)
    end

    def visit(node : StringLiteral)
      @last = build_string_constant(node.value)
    end

    def build_string_constant(str, name = "str")
      # name = name.gsub('@', '.')
      @strings.fetch_or_assign(str) do
        global = @llvm_mod.globals.add(LLVM::ArrayType.new(LLVM::Int8, str.length + 5), name)
        global.linkage = LibLLVM::Linkage::Private
        global.global_constant = true

        # Pack the string bytes
        bytes = [] of LibLLVM::ValueRef
        length = str.length
        length_ptr = length.ptr.as(UInt8)
        (0..3).each { |i| bytes << LLVM::Int8.from_i(length_ptr[i]) }
        str.each_char { |c| bytes << LLVM::Int8.from_i(c.ord) }
        bytes << LLVM::Int8.from_i(0)

        global.initializer = LLVM::Value.const_array(LLVM::Int8, bytes)
        cast_to global.value, @mod.string
      end
    end

    def cast_to(value, type)
      @builder.bit_cast(value, llvm_type(type))
    end

    def visit(node : Assign)
      codegen_assign_node(node.target, node.value)
    end

    def visit(node : Var)
      var = @vars[node.name]
      @last = @builder.load(var.pointer)
      # if var[:type] == node.type
      #   @last = var[:ptr]
      #   @last = @builder.load(@last, node.name) unless (var[:treated_as_pointer] || var[:type].union?)
      # elsif var[:type].nilable?
      #   if node.type.nil_type?
      #     @last = null_pointer?(var[:ptr])
      #   else
      #     @last = var[:ptr]
      #     @last = @builder.load(@last, node.name) unless (var[:treated_as_pointer] || var[:type].union?)
      #   end
      # else
      #   if node.type.union?
      #     @last = cast_to_pointer var[:ptr], node.type
      #   else
      #     value_ptr = union_value(var[:ptr])
      #     @last = cast_to_pointer value_ptr, node.type
      #     @last = @builder.load(@last) unless node.type.passed_by_val?
      #   end
      # end
    end

    def codegen_assign_node(target, value)
      if target.is_a?(Ident)
        return false
      end

      # if target.is_a?(ClassVar) && target.class_scope
      #   global_name = class_var_global_name(target)
      #   in_const_block(global_name) do
      #     accept(value)
      #     llvm_value = @last
      #     ptr = assign_to_global global_name, target.type
      #     codegen_assign(ptr, target.type, value.type, llvm_value)
      #   end
      #   return
      # end

      accept(value)

      # if value.no_returns?
      #   return
      # end

      codegen_assign_target(target, value, @last) if @last

      false
    end

    def codegen_assign_target(target, value, llvm_value)
      case target
      # when InstanceVar
      #   ivar = @type.lookup_instance_var(target.name.to_s)
      #   ptr = gep llvm_self_ptr, 0, @type.index_of_instance_var(target.name.to_s)
      # when Global
      #   ptr = assign_to_global target.name.to_s, target.type
      # when ClassVar
      #   ptr = assign_to_global class_var_global_name(target), target.type
      # else
      when Var
        var = declare_var(target)
        ptr = var.pointer
        codegen_assign(ptr, target.type, value.type, llvm_value)
      else
        raise "Unknown assign target type: #{target}"
      end

      # codegen_assign(ptr, target.type, value.type, llvm_value)
    end

    def codegen_assign(pointer, target_type, value_type, value, instance_var = false)
      if target_type == value_type
        # value = @builder.load value if target_type.union? || (instance_var && (target_type.c_struct? || target_type.c_union?))
        @builder.store value, pointer
      else
        raise "Not implemented: assign_to_union"
        # assign_to_union(pointer, target_type, value_type, value)
      end
    end

    def declare_var(var)
      @vars.fetch_or_assign(var.name.to_s) do
        llvm_var = LLVMVar.new(alloca(llvm_type(var.type), var.name.to_s), var.type)
        # if var.type.is_a?(UnionType) && union_type_id = var.type.types.any?(&:nil_type?)
        #   in_alloca_block { assign_to_union(llvm_var[:ptr], var.type, @mod.nil, llvm_nil) }
        # end
        llvm_var
      end
    end

    # def new_entry_block
    #   @alloca_block, @entry_block = new_entry_block_chain "alloca", "entry"
    # end

    def new_entry_block_chain names
      blocks = new_blocks names
      @builder.position_at_end blocks.last
      blocks
    end

    # def br_from_alloca_to_entry
    #   br_block_chain @alloca_block, @entry_block
    # end

    def br_block_chain blocks
      old_block = @builder.insert_block

      0.upto(blocks.count - 2) do |i|
        @builder.position_at_end blocks[i]
        @builder.br blocks[i + 1]
      end

      @builder.position_at_end old_block
    end

    def new_block(name)
      @fun.append_basic_block(name)
    end

    def new_blocks(names)
      names.map { |name| new_block name }
    end

    def alloca(type, name = "")
      in_alloca_block { @builder.alloca type, name }
    end

    def in_alloca_block
      old_block = @builder.insert_block
      @builder.position_at_end @alloca_block
      value = yield
      @builder.position_at_end old_block
      value
    end

    def llvm_type(type)
      @llvm_typer.llvm_type(type)
    end

    def accept(node)
      # old_current_node = @current_node
      node.accept self
      # @current_node = old_current_node
    end
  end
end
