# Ported from https://github.com/Wilfred/Brainfrack/blob/5a2f613f9e82bfd57be687aa6a67aca15d3d9861/llvm/compiler.cpp

require "llvm"

NUM_CELLS          = 30000
CELL_SIZE_IN_BYTES =     1

def error(message)
  puts message
  exit 1
end

abstract class Instruction
  abstract def compile(program, bb)
end

class Increment < Instruction
  def initialize(@amount : Int32)
  end

  def compile(program, bb)
    builder = program.builder
    builder.position_at_end bb

    cell_index = builder.load program.cell_index_ptr, "cell_index"
    current_cell_ptr = builder.gep program.cells_ptr, cell_index, "current_cell_ptr"

    cell_val = builder.load current_cell_ptr, "cell_value"
    increment_amount = program.ctx.int(CELL_SIZE_IN_BYTES * 8).const_int(@amount)
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

    cell_index = builder.load program.cell_index_ptr, "cell_index"
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

    cell_index = builder.load program.cell_index_ptr, "cell_index"
    current_cell_ptr = builder.gep program.cells_ptr, cell_index, "current_cell_ptr"

    getchar = program.mod.functions["getchar"]
    input_char = builder.call getchar, "input_char"
    input_byte = builder.trunc input_char, program.ctx.int8, "input_byte"
    builder.store input_byte, current_cell_ptr

    bb
  end
end

class Write < Instruction
  def compile(program, bb)
    builder = program.builder
    builder.position_at_end bb

    cell_index = builder.load program.cell_index_ptr, "cell_index"
    current_cell_ptr = builder.gep program.cells_ptr, cell_index, "current_cell_ptr"

    cell_val = builder.load current_cell_ptr, "cell_value"
    cell_val_as_char = builder.sext cell_val, program.ctx.int32, "cell_val_as_char"

    putchar = program.mod.functions["putchar"]
    builder.call putchar, cell_val_as_char

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
    cell_index = builder.load program.cell_index_ptr, "cell_index"
    current_cell_ptr = builder.gep program.cells_ptr, cell_index, "current_cell_ptr"
    cell_val = builder.load current_cell_ptr, "cell_value"
    zero = program.ctx.int(CELL_SIZE_IN_BYTES * 8).const_int(0)
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
  getter! cells_ptr : LLVM::Value
  getter! cell_index_ptr : LLVM::Value
  getter! func : LLVM::Function

  def initialize(@instructions : Array(Instruction))
    @ctx = LLVM::Context.new
    @mod = @ctx.new_module("brainfuck")
    @builder = @ctx.new_builder
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
          error "Unmatched '[' at position #{i}"
        end
        program << Loop.new(parse(source, i + 1, matching_close_index))
        i = matching_close_index
      when ']'
        error "Unmatched ']' at position #{i}"
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
    mod.functions.add "calloc", [@ctx.int32, @ctx.int32], @ctx.void_pointer
    mod.functions.add "free", [@ctx.void_pointer], @ctx.void
    mod.functions.add "putchar", [@ctx.int32], @ctx.int32
    mod.functions.add "getchar", ([] of LLVM::Type), @ctx.int32
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
    @cells_ptr = builder.call calloc, call_args, "cells"

    @cell_index_ptr = builder.alloca @ctx.int32, "cell_index_ptr"
    zero = @ctx.int32.const_int(0)
    builder.store zero, cell_index_ptr
  end

  def add_cells_cleanup(mod, bb)
    builder.position_at_end bb

    free = mod.functions["free"]
    builder.call free, cells_ptr

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
  error "Missing filename"
end

unless File.file?(filename)
  error "'#{filename} is not a file"
end

source = File.read(filename)
program = Program.new(source)
mod = program.compile

output_name = get_output_name(filename)
File.open(output_name, "w") do |file|
  mod.to_s(file)
end
