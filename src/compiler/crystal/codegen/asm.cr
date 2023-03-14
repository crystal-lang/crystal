require "./codegen"

class Crystal::CodeGenVisitor
  def visit(node : Asm)
    constraints = IO::Memory.new

    if outputs = node.outputs
      ptrofs = node.output_ptrofs.not_nil!

      output_types = [] of LLVM::Type
      outputs.each_with_index do |output, i|
        constraints << ',' if i > 0
        constraints << output.constraint

        output_types << llvm_type(ptrofs[i].type.as(PointerInstanceType).element_type)
      end

      if output_types.size > 1
        output_type = @llvm_context.struct(output_types)
      else
        output_type = output_types[0]
      end
    else
      output_type = llvm_context.void
    end

    input_types = [] of LLVM::Type
    input_values = [] of LLVM::Value

    if inputs = node.inputs
      constraints << ',' unless constraints.empty?

      inputs.each_with_index do |input, i|
        accept input.exp
        input_types << llvm_type(input.exp.type)
        input_values << @last
        constraints << ',' if i > 0
        constraints << input.constraint
      end
    end

    if clobbers = node.clobbers
      constraints << ',' unless constraints.empty?

      clobbers.each_with_index do |clobber, i|
        constraints << ',' if i > 0
        constraints << "~{"
        constraints << clobber
        constraints << '}'
      end
    end

    fun_type = LLVM::Type.function(input_types, output_type)
    constraints = constraints.to_s

    value = fun_type.inline_asm(node.text, constraints, node.volatile?, node.alignstack?, node.can_throw?)
    value = LLVM::Function.from_value(value)
    asm_value = call LLVMTypedFunction.new(fun_type, value), input_values

    if ptrofs = node.output_ptrofs
      if ptrofs.size > 1
        ptrofs.each_with_index do |ptrof, i|
          accept ptrof
          store extract_value(asm_value, i), @last
        end
      else
        accept ptrofs[0]
        store asm_value, @last
      end
    end

    @last = llvm_nil

    false
  end
end
