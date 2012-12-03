require 'llvm/core'
require 'llvm/execution_engine'
require 'llvm/transforms/scalar'

LLVM.init_x86

module Crystal
  class ASTNode
    def llvm_type
      type.llvm_type
    end
  end

  class Def
    def mangled_name(self_type)
      Def.mangled_name(self_type, owner, name, (body ? body.type : nil), args.map(&:type))
    end

    def self.mangled_name(self_type, owner, name, return_type, arg_types)
      str = '*'
      if owner
        if owner.is_a?(Metaclass)
          str << owner.type.name
          str << '::'
        elsif !owner.is_a?(Crystal::Program)
          str << owner.llvm_name
          str << '#'
        end
      end
      str << name.to_s.gsub('@', '.')
      str << '<'
      if self_type
        str << self_type.llvm_name
      end
      if arg_types.length > 0
        str << ', ' if self_type
        str << arg_types.map(&:llvm_name).join(', ')
      end
      str << '>'
      if return_type
        str << ':'
        str << return_type.llvm_name
      end
      str
    end
  end

  def run(code, options = {})
    node = parse code
    mod = infer_type node, options
    llvm_mod = build node, mod

    engine = LLVM::JITCompiler.new(llvm_mod)
    engine.run_function llvm_mod.functions["crystal_main"], 0, nil
  end

  def build(node, mod)
    visitor = CodeGenVisitor.new(mod, node ? node.type : mod.void)
    if node
      begin
        node.accept visitor
      rescue StandardError => ex
        visitor.llvm_mod.dump
        raise
      end
    end

    visitor.finish

    visitor.llvm_mod.dump if Crystal::DUMP_LLVM

    visitor.llvm_mod.verify

    visitor.llvm_mod
  end

  class CrystalBuilder
    def initialize(builder)
      @builder = builder
    end

    def ret(*args)
      return if @end
      @builder.ret *args
      @end = true
    end

    def br(*args)
      return if @end
      @builder.br *args
      @end = true
    end

    def position_at_end(*args)
      @builder.position_at_end *args
      @end = false
    end

    def insert_block(*args)
      @builder.insert_block *args
    end

    def method_missing(name, *args)
      return if @end
      @builder.send name, *args
    end
  end

  class CodeGenVisitor < Visitor
    attr_reader :llvm_mod

    def initialize(mod, return_type)
      @mod = mod
      @return_type = return_type
      @llvm_mod = LLVM::Module.new("Crystal")
      @fun = @llvm_mod.functions.add("crystal_main", [LLVM::Int, LLVM::Pointer(LLVM::Pointer(LLVM::Int8))], return_type.llvm_type)

      @argc = @fun.params[0]
      @argc.name = 'argc'

      @argv = @fun.params[1]
      @argv.name = 'argv'

      @builder = CrystalBuilder.new LLVM::Builder.new

      @alloca_block, @const_block, @entry_block = new_entry_block_chain "alloca", "const", "entry"

      @funs = {}
      @vars = {}
      @block_context = []
      @type = @mod

      @symbols = {}
      symbol_table_values = []
      mod.symbols.to_a.sort.each_with_index do |sym, index|
        @symbols[sym] = index
        symbol_table_values << @builder.bit_cast(@builder.global_string_pointer(sym, sym), mod.string.llvm_type)
      end

      symbol_table = @llvm_mod.globals.add(LLVM::Array(mod.string.llvm_type, symbol_table_values.count), "symbol_table")
      symbol_table.linkage = :internal
      symbol_table.initializer = LLVM::ConstantArray.const(mod.string.llvm_type, symbol_table_values)
    end

    def main
      @fun
    end

    def finish
      br_block_chain @alloca_block, @const_block, @entry_block
      @builder.ret(@return_type == @mod.void ? nil : @last)
    end

    def visit_nil_literal(node)
      @last = LLVM::Int1.from_i(0)
    end

    def visit_bool_literal(node)
      @last = LLVM::Int1.from_i(node.value ? 1 : 0)
    end

    def visit_int_literal(node)
      @last = LLVM::Int(node.value)
    end

    def visit_long_literal(node)
      @last = LLVM::Int64.from_i(node.value)
    end

    def visit_float_literal(node)
      @last = LLVM::Float(node.value)
    end

    def visit_char_literal(node)
      @last = LLVM::Int8.from_i(node.value)
    end

    def visit_string_literal(node)
      @last = @builder.bit_cast(@builder.global_string_pointer(node.value), node.type.llvm_type)
    end

    def visit_symbol_literal(node)
      @last = LLVM::Int32.from_i(@symbols[node.value])
    end

    def visit_expressions(node)
      node.expressions.each do |exp|
        exp.accept self
        break if exp.is_a?(Return)
      end
      false
    end

    def end_visit_return(node)
      if @return_block
        @builder.br @return_block
      else
        @builder.ret @last
      end
    end

    def visit_lib_def(node)
      false
    end

    def visit_ident(node)
      const = node.target_const
      global_name = const.full_name
      global = @llvm_mod.globals[global_name]

      unless global
        global = @llvm_mod.globals.add(const.value.type.llvm_type, global_name)
        global.linkage = :internal

        old_position = @builder.insert_block
        @builder.position_at_end @const_block

        const.value.accept self
        if @last.constant?
          global.initializer = @last
          global.global_constant = 1
        else
          global.initializer = LLVM::Constant.null(@last.type)
          @builder.store @last, global
        end

        @builder.position_at_end old_position
      end

      @last = @builder.load global
    end

    def visit_assign(node)
      if node.target.is_a?(Ident)
        return false
      end

      node.value.accept self

      case node.target
      when InstanceVar
        ivar = @type.instance_vars[node.target.name.to_s]
        ptr = gep llvm_self, 0, @type.index_of_instance_var(node.target.name.to_s)
      when Global
        ptr = @llvm_mod.globals[node.target.name.to_s]
        unless ptr
          ptr = @llvm_mod.globals.add(node.target.llvm_type, node.target.name.to_s)
          ptr.linkage = :internal
          ptr.initializer = LLVM::Constant.null(node.target.llvm_type)
        end
      else
        var = @vars[node.target.name.to_s]
        unless var
          var = @vars[node.target.name.to_s] = {
            ptr: alloca(node.target.llvm_type, node.target.name.to_s),
            type: node.target.type
          }
        end
        ptr = var[:ptr]
      end

      codegen_assign(ptr, node.target.type, node.value.type, @last)

      false
    end

    def visit_var(node)
      var = @vars[node.name]
      @last = var[:ptr]
      @last = @builder.load @last, node.name unless var[:is_arg] || var[:type].is_a?(UnionType)
    end

    def visit_global(node)
      if @mod.global_vars[node.name].type.is_a?(UnionType)
        @last = @llvm_mod.globals[node.name]
      else
        @last = @builder.load @llvm_mod.globals[node.name]
      end
    end

    def visit_instance_var(node)
      ivar = @type.instance_vars[node.name]
      if ivar.type.is_a?(UnionType)
        @last = gep llvm_self, 0, @type.index_of_instance_var(node.name)
      else
        index = @type.index_of_instance_var(node.name)
        struct = @builder.load llvm_self
        @last = @builder.extract_value struct, index, node.name
      end
    end

    def visit_pointer_of(node)
      if node.var.is_a?(Var)
        var = @vars[node.var.name]
        @last = var[:ptr]
      else
        var = @type.instance_vars[node.var.name]
        @last = gep llvm_self, 0, @type.index_of_instance_var(node.var.name)
      end
      false
    end

    def visit_pointer_malloc(node)
      @last = @builder.array_malloc(node.type.var.llvm_type, @vars['size'][:ptr])
    end

    def visit_pointer_realloc(node)
      casted_ptr = @builder.bit_cast llvm_self, LLVM::Pointer(LLVM::Int8)
      reallocated_ptr = realloc casted_ptr, @vars['size'][:ptr]
      @last = @builder.bit_cast reallocated_ptr, LLVM::Pointer(@type.var.llvm_type)
    end

    def visit_pointer_get_value(node)
      if @type.var.type.is_a?(UnionType)
        @last = llvm_self
      else
        @last = @builder.load llvm_self
      end
    end

    def visit_pointer_set_value(node)
      codegen_assign llvm_self, @type.var.type, node.type, @fun.params[1]
      @last = @fun.params[1]
    end

    def visit_pointer_add(node)
      @last = gep(llvm_self, @fun.params[1])
    end

    def visit_pointer_cast(node)
      @last = @builder.bit_cast(@fun.params[0], node.type.llvm_type)
    end

    def visit_if(node)
      is_union = node.else && node.type.is_a?(UnionType)

      then_block, exit_block = new_blocks "then", "exit"
      else_block = new_block "else" if node.else

      union_ptr = alloca node.llvm_type if is_union
      node.cond.accept self

      @builder.cond(@last, then_block, node.else ? else_block : exit_block)

      @builder.position_at_end then_block
      node.then.accept self
      then_block = @builder.insert_block

      then_value = @last
      codegen_assign(union_ptr, node.type, node.then.type, @last) if is_union

      @builder.br exit_block

      if node.else
        @builder.position_at_end else_block
        node.else.accept self
        else_block = @builder.insert_block

        else_value = @last
        codegen_assign(union_ptr, node.type, node.else.type, @last) if is_union

        @builder.br exit_block

        @builder.position_at_end exit_block

        if is_union
          @last = union_ptr
        elsif node.type
          @last = @builder.phi node.llvm_type, {then_block => then_value, else_block => else_value}
        else
          @last = nil
        end
      else
        @builder.position_at_end exit_block
      end

      false
    end

    def visit_while(node)
      while_block, body_block, exit_block = new_blocks "while", "body", "exit"

      @builder.br while_block

      @builder.position_at_end while_block
      node.cond.accept self

      @builder.cond(@last, body_block, exit_block)

      @builder.position_at_end body_block
      node.body.accept self if node.body
      @builder.br while_block

      @builder.position_at_end exit_block

      false
    end

    def visit_def(node)
      false
    end

    def visit_macro(node)
      false
    end

    def visit_class_def(node)
      false
    end

    def visit_struct_def(node)
      false
    end

    def visit_include(node)
      false
    end

    def visit_primitive_body(node)
      @last = node.block.call(@builder, @fun, @llvm_mod, @type)
    end

    def visit_alloc(node)
      @last = malloc node.type.llvm_struct_type
      memset @last, LLVM::Int(0), node.type.llvm_struct_type.size
      @last
    end

    def visit_struct_alloc(node)
      @last = malloc node.type.llvm_struct_type
      memset @last, LLVM::Int(0), node.type.llvm_struct_type.size
      @last
    end

    def visit_struct_get(node)
      var = @type.vars[node.name]

      index = @type.index_of_var(node.name)
      struct = @builder.load llvm_self
      @last = @builder.extract_value struct, index, node.name
    end

    def visit_struct_set(node)
      var = @type.vars[node.name]
      ptr = gep llvm_self, 0, @type.index_of_var(node.name)
      @builder.store @last, ptr
    end

    def visit_array_literal(node)
      size = node.elements.length
      capacity = size < 16 ? 16 : 2 ** Math.log(size, 2).ceil

      array = @builder.malloc(node.type.llvm_struct_type)
      @builder.store LLVM::Int(size), gep(array, 0, 0)
      @builder.store LLVM::Int(capacity), gep(array, 0, 1)

      buffer = @builder.array_malloc(node.type.element_llvm_type, LLVM::Int(capacity))
      @builder.store buffer, gep(array, 0, 2)

      node.elements.each_with_index do |elem, index|
        elem.accept self
        codegen_assign gep(buffer, index), node.type.element_type, elem.type, @last
      end

      @last = array

      false
    end

    def visit_array_new(node)
      size = @vars['size'][:ptr]
      capacity = size # TODO: expand to next power of two using LLVM

      obj = @vars['obj']

      array = @builder.malloc(node.type.llvm_struct_type)
      @builder.store size, gep(array, 0, 0)
      @builder.store capacity, gep(array, 0, 1)

      buffer = @builder.array_malloc(node.type.element_llvm_type, capacity)
      @builder.store buffer, gep(array, 0, 2)

      case node.type.element_type
      when @mod.bool, @mod.char
        memset buffer, @builder.zext(obj[:ptr], LLVM::Int), size
      when @mod.int
        codegen_int_array_new_contents(node, buffer, obj, size)
      else
        codegen_array_new_contents(node, buffer, obj, size)
      end

      @last = array
    end

    def codegen_int_array_new_contents(node, buffer, obj, size)
      memset_block, one_by_one_block, exit_block = new_blocks 'memset', 'one_by_one', 'exit'

      cmp = @builder.icmp :eq, obj[:ptr], LLVM::Int(0)
      @builder.cond cmp, memset_block, one_by_one_block

      @builder.position_at_end memset_block
      bytes_count = @builder.mul size, LLVM::Int(@mod.int.llvm_size)
      memset buffer, obj[:ptr], bytes_count
      @builder.br exit_block

      @builder.position_at_end one_by_one_block
      codegen_array_new_contents(node, buffer, obj, size)
      @builder.br exit_block

      @builder.position_at_end exit_block
    end

    def codegen_array_new_contents(node, buffer, obj, size)
      cmp_block, loop_block, exit_block = new_blocks 'cmp', 'loop', 'exit'

      index_ptr = alloca LLVM::Int
      @builder.store LLVM::Int(0), index_ptr

      @builder.br cmp_block

      @builder.position_at_end cmp_block
      cmp = @builder.icmp(:eq, @builder.load(index_ptr), size)
      @builder.cond(cmp, exit_block, loop_block)

      @builder.position_at_end loop_block
      index = @builder.load(index_ptr)
      codegen_assign gep(buffer, index), node.type.element_type, obj[:type], obj[:ptr]
      @builder.store @builder.add(index, LLVM::Int(1)), index_ptr
      @builder.br cmp_block

      @builder.position_at_end exit_block
    end

    def visit_array_length(node)
      if @type.element_type
        @last = @builder.load gep(llvm_self, 0, 0)
      else
        @last = LLVM::Int(0)
      end
    end

    def visit_array_get(node)
      @last = array_index_pointer
      @last = @builder.load @last unless @type.element_type.is_a?(UnionType)
    end

    def visit_array_set(node)
      codegen_assign(array_index_pointer, @type.element_type, node.type, @fun.params[2])
      @last = @fun.params[2]
    end

    def visit_array_push(node)
      resize_block, exit_block = new_blocks "resize", "exit"

      size_ptr = gep(llvm_self, 0, 0)
      capacity_ptr = gep(llvm_self, 0, 1)
      size = @builder.load size_ptr
      capacity = @builder.load capacity_ptr
      cmp = @builder.icmp(:eq, size, capacity)
      @builder.cond(cmp, resize_block, exit_block)

      @builder.position_at_end resize_block
      buffer_ptr = gep(llvm_self, 0, 2)
      new_capacity = @builder.mul capacity, LLVM::Int(2)
      llvm_type = @type.element_llvm_type
      llvm_type = llvm_type.is_a?(LLVM::Type) ? llvm_type : llvm_type.type
      new_buffer_size = @builder.mul new_capacity, @builder.trunc(llvm_type.size, LLVM::Int32)
      buffer = @builder.load buffer_ptr
      casted_buffer = @builder.bit_cast buffer, LLVM::Pointer(LLVM::Int8)
      realloced_pointer = realloc casted_buffer, new_buffer_size
      casted_realloced_pointer = @builder.bit_cast realloced_pointer, LLVM::Pointer(@type.element_llvm_type)
      @builder.store casted_realloced_pointer, buffer_ptr
      @builder.store new_capacity, capacity_ptr
      @builder.br exit_block

      @builder.position_at_end exit_block
      new_size = @builder.add size, LLVM::Int(1)
      @builder.store new_size, size_ptr
      codegen_assign(array_index_pointer(size), @type.element_type, @vars['value'][:type], @fun.params[1])
      @last = llvm_self
    end

    def array_index_pointer(index = @fun.params[1])
      buffer = @builder.load gep(llvm_self, 0, 2)
      gep(buffer, index)
    end

    def visit_argv(node)
      array = @builder.malloc(node.type.llvm_struct_type)

      length = @builder.sub(@argc, LLVM::Int(1))

      @builder.store LLVM::Int(length), gep(array, 0, 0)
      @builder.store LLVM::Int(length), gep(array, 0, 1)

      # Pointer to the second element
      argv_ptr = gep(@argv, 1)
      argv_ptr_as_string = @builder.bit_cast(argv_ptr, LLVM::Pointer(@mod.string.llvm_type))
      @builder.store argv_ptr_as_string, gep(array, 0, 2)

      @last = array
    end

    def visit_call(node)
      if node.target_macro
        node.target_macro.accept self
        return false
      end

      if node.target_def.is_a?(Dispatch)
        codegen_dispatch(node)
        return false
      end

      owner = ((node.obj && node.obj.type) || node.scope)
      owner = node.target_def.owner && owner.is_a?(Type) && !owner.is_a?(Metaclass) && !owner.is_a?(Program) && owner

      call_args = []
      if node.obj && node.obj.type.passed_as_self?
        node.obj.accept self
        call_args << @last
      elsif owner
        call_args << llvm_self
      end

      node.args.each do |arg|
        next if arg.type.is_a?(Metaclass)
        arg.accept self
        call_args << @last
      end

      if node.block
        @block_context << { block: node.block, vars: @vars, type: @type, return_block: @return_block }
        @vars = {}

        if owner && owner.passed_as_self?
          @type = owner
          args_base_index = 1
          @vars['self'] = { ptr: call_args[0], type: owner, is_arg: true }
        else
          args_base_index = 0
        end

        node.target_def.args.each_with_index do |arg, i|
          ptr = alloca(arg.llvm_type, arg.name)
          @vars[arg.name] = { ptr: ptr, type: arg.type }
          @builder.store call_args[args_base_index + i], ptr
        end

        @return_block = new_block 'return'
        node.target_def.body.accept self
        @builder.br @return_block
        @builder.position_at_end @return_block

        old_context = @block_context.pop
        @vars = old_context[:vars]
        @type = old_context[:type]
        @return_block = old_context[:return_block]
      else
        codegen_call(node.target_def, owner, call_args)
      end

      false
    end

    def visit_yield(node)
      if @block_context.any?
        context = @block_context.pop
        new_vars = context[:vars].clone
        block = context[:block]

        block.args.each_with_index do |arg, i|
          node.exps[i].accept self
          new_vars[arg.name] = { ptr: @last, type: arg.type, is_arg: true }
        end

        old_vars = @vars
        old_type = @type
        old_return_block = @return_block
        @vars = new_vars
        @type = context[:type]
        @return_block = context[:return_block]

        block.accept self

        @vars = old_vars
        @type = old_type
        @return_block = old_return_block
        @block_context << context
      end
      false
    end

    def codegen_call(target_def, self_type, call_args)
      mangled_name = target_def.mangled_name(self_type)

      old_fun = @fun
      unless @fun = @funs[mangled_name]
        codegen_fun(mangled_name, target_def, self_type)
      end

      @last = @builder.call @fun, *call_args

      if target_def.body && target_def.body.type.is_a?(UnionType)
        union = alloca target_def.body.llvm_type
        @builder.store @last, union
        @last = union
      end

      @fun = old_fun
    end

    def codegen_fun(mangled_name, target_def, self_type)
      old_position = @builder.insert_block
      old_vars = @vars
      old_type = @type
      old_entry_block = @entry_block
      old_alloca_block = @alloca_block

      @vars = {}

      args = []
      if self_type && self_type.passed_as_self?
        @type = self_type
        args << Var.new("self", self_type)
      end
      args += target_def.args.select { |arg| !arg.type.is_a?(Metaclass) }

      @fun = @funs[mangled_name] = @llvm_mod.functions.add(
        mangled_name,
        args.map(&:llvm_type),
        target_def.body.llvm_type
      )

      args.each_with_index do |arg, i|
        @fun.params[i].name = arg.name
      end

      unless target_def.is_a? External
        @fun.linkage = :internal
        new_entry_block

        args.each_with_index do |arg, i|
          if self_type && i == 0 || target_def.body.is_a?(Primitive)
            @vars[arg.name] = { ptr: @fun.params[i], type: arg.type, is_arg: true }
          else
            ptr = alloca(arg.llvm_type, arg.name)
            @vars[arg.name] = { ptr: ptr, type: arg.type }
            @builder.store @fun.params[i], ptr
          end
        end

        if target_def.body
          target_def.body.accept self
          if target_def.body.type.is_a?(UnionType)
            @last = @builder.load @last
          end

          @builder.ret(target_def.body.type == @mod.void ? nil : @last)
        else
          @builder.ret_void
        end

        br_from_alloca_to_entry

        @builder.position_at_end old_position
      end

      @vars = old_vars
      @type = old_type
      @entry_block = old_entry_block
      @alloca_block = old_alloca_block
    end

    def codegen_dispatch(node)
      dispatch = node.target_def

      unreachable_block, exit_block = new_blocks "unreachable", "exit"

      phi_table = {}
      arg_types = []
      arg_values = []

      codegen_dispatch_arg(node, arg_types, arg_values, unreachable_block) do |label|
        call = dispatch.calls[arg_types.map(&:object_id)]
        codegen_call(call.target_def, (node.obj ? arg_types[0] : nil), arg_values)

        if dispatch.type.is_a?(UnionType)
          phi_table[label] = phi_value = alloca dispatch.llvm_type
          assign_to_union(phi_value, dispatch.type, call.type, @last)
        else
          phi_table[label] = @last
        end

        @builder.br exit_block
      end

      @builder.position_at_end unreachable_block
      @builder.unreachable

      @builder.position_at_end exit_block

      if dispatch.type.is_a?(UnionType)
        @last = @builder.phi LLVM::Pointer(dispatch.llvm_type), phi_table
      else
        @last = @builder.phi dispatch.llvm_type, phi_table
      end

      false
    end

    def codegen_dispatch_arg(node, arg_types, arg_values, unreachable_block, arg_index = -1, previous_label = nil, &block)
      arg = arg_index == -1 ? node.obj : node.args[arg_index]
      arg.accept self if arg

      if arg && arg.type.is_a?(UnionType)
        arg_ptr = @last
        index_ptr, value_ptr = union_index_and_value(arg_ptr)

        switch_table = {}

        old_block = @builder.insert_block
        arg.type.types.each_with_index.each do |arg_type, i|
          label = new_block "type_#{i}"
          @builder.position_at_end label

          casted_value_ptr = @builder.bit_cast value_ptr, LLVM::Pointer(arg_type.llvm_type)
          value = @builder.load casted_value_ptr

          codegen_dispatch_next_arg node, arg_types, arg_values, arg_type, value, unreachable_block, arg_index, label, &block

          switch_table[LLVM::Int(i)] = label
        end

        @builder.position_at_end old_block

        type_index = @builder.load index_ptr
        @builder.switch type_index, unreachable_block, switch_table
      else
        codegen_dispatch_next_arg node, arg_types, arg_values, (arg ? arg.type : nil), @last, unreachable_block, arg_index, previous_label, &block
      end
    end

    def codegen_dispatch_next_arg(node, arg_types, arg_values, arg_type, arg_value, unreachable_block, arg_index, label, &block)
      arg_types.push arg_type
      arg_values.push arg_value unless arg_index == -1 && !node.obj

      if arg_index == node.args.length - 1
        block.call(label)
      else
        codegen_dispatch_arg(node, arg_types, arg_values, unreachable_block, arg_index + 1, label, &block)
      end

      arg_types.pop
      arg_values.pop
    end

    def codegen_assign(pointer, target_type, value_type, value)
      if target_type == value_type
        if target_type.is_a?(UnionType)
          value = @builder.load value
          @builder.store value, pointer
        else
          @builder.store value, pointer
        end
      else
        assign_to_union(pointer, target_type, value_type, value)
      end
    end

    def assign_to_union(union_pointer, union_type, type, value)
      index_ptr, value_ptr = union_index_and_value(union_pointer)

      index = union_type.index_of_type(type)
      @builder.store LLVM::Int(index), index_ptr

      casted_value_ptr = @builder.bit_cast value_ptr, LLVM::Pointer(type.llvm_type)
      @builder.store value, casted_value_ptr
    end

    def union_index_and_value(union_pointer)
      index_ptr = gep union_pointer, 0, 0
      value_ptr = gep union_pointer, 0, 1
      [index_ptr, value_ptr]
    end

    def gep(ptr, *indices)
      @builder.gep ptr, indices.map { |i| LLVM::Int(i) }
    end

    def malloc(type)
      @builder.malloc(type)
    end

    def memset(pointer, value, size)
      pointer = @builder.bit_cast pointer, LLVM::Pointer(LLVM::Int8)
      @builder.call @mod.memset(@llvm_mod), pointer, value, @builder.trunc(size, LLVM::Int32)
    end

    def realloc(buffer, size)
      @builder.call @mod.realloc(@llvm_mod), buffer, size
    end

    def alloca(type, name = '')
      old_block = @builder.insert_block
      @builder.position_at_end @alloca_block
      ptr = @builder.alloca type, name
      @builder.position_at_end old_block
      ptr
    end

    def llvm_self
      @vars['self'][:ptr]
    end

    def new_entry_block
      @alloca_block, @entry_block = new_entry_block_chain "alloca", "entry"
    end

    def new_entry_block_chain *names
      blocks = new_blocks *names
      @builder.position_at_end blocks.last
      blocks
    end

    def br_from_alloca_to_entry
      br_block_chain @alloca_block, @entry_block
    end

    def br_block_chain *blocks
      old_block = @builder.insert_block

      0.upto(blocks.count - 2) do |i|
        @builder.position_at_end blocks[i]
        @builder.br blocks[i + 1]
      end

      @builder.position_at_end old_block
    end

    def new_block(name)
      @fun.basic_blocks.append(name)
    end

    def new_blocks(*names)
      names.map { |name| new_block name }
    end
  end
end