require "./codegen"

class Crystal::CodeGenVisitor
  def visit(node : Asm)
    constraints = IO::Memory.new

    if ptrof = node.ptrof
      output = node.output.not_nil!
      output_type = llvm_type(ptrof.type.as(PointerInstanceType).element_type)
      constraints << output.constraint
    else
      output_type = llvm_context.void
    end

    input_types = [] of LLVM::Type
    input_values = [] of LLVM::Value

    if inputs = node.inputs
      constraints << "," unless constraints.empty?

      inputs.each_with_index do |input, i|
        input.exp.accept self
        input_types << llvm_type(input.exp.type)
        input_values << @last
        constraints << "," if i > 0
        constraints << input.constraint
      end
    end

    if clobbers = node.clobbers
      constraints << "," unless constraints.empty?

      clobbers.each_with_index do |clobber, i|
        constraints << "," if i > 0
        constraints << "~{"
        constraints << clobber
        constraints << '}'
      end
    end

    fun_type = LLVM::Type.function(input_types, output_type)
    constraints = constraints.to_s

    value = fun_type.const_inline_asm(node.text, constraints, node.volatile?, node.alignstack?)
    asm_value = call value, input_values

    if ptrof
      ptrof.accept self
      store asm_value, @last
    end

    @last = llvm_nil

    false
  end
end
