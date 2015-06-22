require "./codegen"

class Crystal::CodeGenVisitor
  def visit(node : Asm)
    constraints = StringIO.new

    if ptrof = node.ptrof
      output = node.output.not_nil!
      output_type = llvm_type((ptrof.type as PointerInstanceType).element_type)
      constraints << output.constraint
    else
      output_type = LLVM::Void
    end

    input_types = [] of LLVM::Type
    input_values = [] of LLVM::Value

    if inputs = node.inputs
      constraints << "," if output

      inputs.try &.each_with_index do |input, i|
        input.exp.accept self
        input_types << llvm_type(input.exp.type)
        input_values << @last
        constraints << "," if i > 0
        constraints << input.constraint
      end
    end

    fun_type = LLVM::Type.function(input_types, output_type)
    constraints = constraints.to_s

    value = LLVM.const_inline_asm(fun_type, node.text, constraints)
    asm_value = call value, input_values

    if ptrof
      ptrof.accept self
      store asm_value, @last
    end

    @last = llvm_nil

    false
  end
end
