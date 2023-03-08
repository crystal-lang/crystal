# Ported from https://github.com/Wilfred/Brainfrack/blob/5a2f613f9e82bfd57be687aa6a67aca15d3d9861/llvm/compiler.cpp

require "llvm"

NUM_CELLS          = 30000
CELL_SIZE_IN_BYTES =     1

abstract class Instruction
  abstract def compile(program, bb)
end

class Increment < Instruction
  def initialize(@amount : Int32)
  end

  def compile(program, bb)
    builder = program.builder
    builder.position_at_end bb

    cell_index = builder.load program.ctx.int32, program.cell_index_ptr, "cell_index"
    current_cell_ptr = builder.gep program.cell_type, program.cells_ptr, cell_index, "current_cell_ptr"

    cell_val = builder.load program.cell_type, current_cell_ptr, "cell_value"
    increment_amount = program.cell_type.const_int(@amount)
    new_cell_val = builder.add cell_val, increment_amount, "cell_value"
    builder.store new_cell_val, current_cell_ptr

    bb
  end
end

class DataIncrement < Instruction
  def initialize(@amount : Int32)
  end

  def compile(program, bb)
    builder = program.builder
    builder.position_at_end bb

    cell_index = builder.load program.ctx.int32, program.cell_index_ptr, "cell_index"
    increment_amount = program.ctx.int32.const_int(@amount)
    new_cell_index = builder.add cell_index, increment_amount, "new_cell_index"

    builder.store new_cell_index, program.cell_index_ptr

    bb
  end
end

class Read < Instruction
  def compile(program, bb)
    builder = program.builder
    builder.position_at_end bb

    cell_index = builder.load program.ctx.int32, program.cell_index_ptr, "cell_index"
    current_cell_ptr = builder.gep program.cell_type, program.cells_ptr, cell_index, "current_cell_ptr"

    input_char = program.call_c_function "getchar", name: "input_char"
    input_byte = builder.trunc input_char, program.ctx.int8, "input_byte"
    builder.store input_byte, current_cell_ptr

    bb
  end
end

class Write < Instruction
  def compile(program, bb)
    builder = program.builder
    builder.position_at_end bb

    cell_index = builder.load program.ctx.int32, program.cell_index_ptr, "cell_index"
    current_cell_ptr = builder.gep program.cell_type, program.cells_ptr, cell_index, "current_cell_ptr"

    cell_val = builder.load program.cell_type, current_cell_ptr, "cell_value"
    cell_val_as_char = builder.sext cell_val, program.ctx.int32, "cell_val_as_char"

    program.call_c_function "putchar", cell_val_as_char

    bb
  end
end

class Loop < Instruction
  def initialize(@body : Array(Instruction))
  end

  def compile(program, bb)
    builder = program.builder
    func = program.func

    loop_header = func.basic_blocks.append "loop_header"

    builder.position_at_end bb
    builder.br loop_header

    loop_body_block = func.basic_blocks.append "loop_body"
    loop_after = func.basic_blocks.append "loop_after"

    builder.position_at_end loop_header
    cell_index = builder.load program.ctx.int32, program.cell_index_ptr, "cell_index"
    current_cell_ptr = builder.gep program.cell_type, program.cells_ptr, cell_index, "current_cell_ptr"
    cell_val = builder.load program.cell_type, current_cell_ptr, "cell_value"
    zero = program.cell_type.const_int(0)
    cell_val_is_zero = builder.icmp LLVM::IntPredicate::EQ, cell_val, zero

    builder.cond cell_val_is_zero, loop_after, loop_body_block

    @body.each do |instruction|
      loop_body_block = instruction.compile(program, loop_body_block)
    end

    builder.position_at_end loop_body_block
    builder.br loop_header

    loop_after
  end
end

class Program
  getter mod : LLVM::Module
  getter ctx : LLVM::Context
  getter builder : LLVM::Builder
  getter instructions
  getter cell_type : LLVM::Type
  getter! cells_ptr : LLVM::Value
  getter! cell_index_ptr : LLVM::Value
  getter! func : LLVM::Function

  @func_types = {} of String => LLVM::Type

  def initialize(@instructions : Array(Instruction))
    @ctx = LLVM::Context.new
    @mod = @ctx.new_module("brainfuck")
    @builder = @ctx.new_builder

    @cell_type = @ctx.int(CELL_SIZE_IN_BYTES * 8)
  end

  def self.new(source : String)
    new source.chars
  end

  def self.new(source : Array(Char))
    new parse(source, 0, source.size)
  end

  def self.parse(source, from, to)
    program = [] of Instruction
    i = from
    while i < to
      case source[i]
      when '+'
        program << Increment.new(1)
      when '-'
        program << Increment.new(-1)
      when '>'
        program << DataIncrement.new(1)
      when '<'
        program << DataIncrement.new(-1)
      when ','
        program << Read.new
      when '.'
        program << Write.new
      when '['
        matching_close_index = find_matching_close(source, i)
        unless matching_close_index
          abort "Unmatched '[' at position #{i}"
        end
        program << Loop.new(parse(source, i + 1, matching_close_index))
        i = matching_close_index
      when ']'
        abort "Unmatched ']' at position #{i}"
      else
        # skip
      end
      i += 1
    end
    program
  end

  def self.find_matching_close(source, open_index)
    open_count = 0
    (open_index...source.size).each do |i|
      case source[i]
      when '['
        open_count += 1
      when ']'
        open_count -= 1
      end

      if open_count == 0
        return i
      end
    end
    nil
  end

  def compile
    declare_c_functions mod
    @func = create_main mod
    bb = func.basic_blocks.append "entry"
    add_cells_init mod, bb
    instructions.each do |instruction|
      bb = instruction.compile(self, bb)
    end
    add_cells_cleanup mod, bb
    mod
  end

  def declare_c_functions(mod)
    declare_c_function mod, "calloc", [@ctx.int32, @ctx.int32], @ctx.void_pointer
    declare_c_function mod, "free", [@ctx.void_pointer], @ctx.void
    declare_c_function mod, "putchar", [@ctx.int32], @ctx.int32
    declare_c_function mod, "getchar", ([] of LLVM::Type), @ctx.int32
  end

  def declare_c_function(mod, name, param_types, return_type)
    func_type = LLVM::Type.function(param_types, return_type)
    @func_types[name] = func_type
    mod.functions.add name, func_type
  end

  def call_c_function(func_name, args = [] of LLVM::Value, name = "")
    func = mod.functions[func_name]
    @builder.call @func_types[func_name], func, args, name
  end

  def create_main(mod)
    main = mod.functions.add "main", ([] of LLVM::Type), @ctx.int32
    main.linkage = LLVM::Linkage::External
    main
  end

  def add_cells_init(mod, bb)
    builder.position_at_end bb

    calloc = mod.functions["calloc"]
    call_args = [@ctx.int32.const_int(NUM_CELLS), @ctx.int32.const_int(CELL_SIZE_IN_BYTES)]
    @cells_ptr = call_c_function "calloc", call_args, "cells"

    @cell_index_ptr = builder.alloca @ctx.int32, "cell_index_ptr"
    zero = @ctx.int32.const_int(0)
    builder.store zero, cell_index_ptr
  end

  def add_cells_cleanup(mod, bb)
    builder.position_at_end bb

    call_c_function "free", cells_ptr

    zero = @ctx.int32.const_int(0)
    builder.ret zero
  end
end

def get_output_name(filename)
  if filename.ends_with?(".bf")
    "#{filename[0..filename.size - 4]}.ll"
  else
    "#{filename}.ll"
  end
end

filename = ARGV.first?
unless filename
  abort "Missing filename"
end

unless File.file?(filename)
  abort "#{filename} is not a file"
end

source = File.read(filename)
program = Program.new(source)
mod = program.compile

output_name = get_output_name(filename)
File.open(output_name, "w") do |file|
  mod.to_s(file)
end
