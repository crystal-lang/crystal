require 'bundler/setup'
require 'pry'
require 'pry-debugger'

if ENV["CI"]
  require 'simplecov'
  require 'coveralls'
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  SimpleCov.start do
    add_filter 'lib/crystal/profiler.rb'
    add_filter 'lib/crystal/graph.rb'
    add_filter 'lib/crystal/print_types_visitor.rb'
  end
end

if ENV["COVERAGE"]
  require 'simplecov'
  SimpleCov.start
end

require(File.expand_path("../../lib/crystal",  __FILE__))

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.filter_run_excluding :integration, :primitives
end

include Crystal

# Escaped regexp
def regex(str)
  /#{Regexp.escape(str)}/
end

def assert_type(str, options = {}, &block)
  program = Program.new
  input = parse str
  input = program.normalize input
  program.infer_type input
  expected_type = program.instance_eval &block
  if input.is_a?(Expressions)
    actual_type = input.last.type
  else
    actual_type = input.type
  end
  actual_type.should eq(expected_type)
  [program, actual_type]
end

def infer_type(node)
  program = Program.new
  node = program.normalize node
  node = program.infer_type node
  [program, node]
end

def assert_error(str, message)
  nodes = parse(str)
  lambda { infer_type nodes }.should raise_error(Crystal::Exception, regex(message))
end

def assert_syntax_error(str, message)
  lambda { parse(str) }.should raise_error(Crystal::SyntaxException, regex(message))
end

def assert_normalize(from, to)
  program = Program.new
  normalizer = Normalizer.new(program)
  from_nodes = Parser.parse(from)
  to_nodes = normalizer.normalize(from_nodes)
  to_nodes.to_s.strip.should eq(to.strip)
end

def assert_after_type_inference(before, after)
  node = parse before
  mod, node = infer_type node
  node.to_s.strip.should eq(after.strip)
end

def run(code)
  program = Program.new
  program.run(code)
end

def build(code)
  program = Program.new
  node = parse code
  node = program.normalize node
  node = program.infer_type node
  program.build node
end

def permutate_primitive_types
  [
    ['UInt8', 'u8'],
    ['UInt16', 'u16'],
    ['UInt32', 'u32'],
    ['UInt64', 'u64'],
    ['Int8', 'i8'],
    ['Int16', 'i16'],
    ['Int32', ''],
    ['Int64', 'i64'],
    ['Float32', 'f32'],
    ['Float64', 'f64']
  ].repeated_permutation(2) do |p1, p2|
    type1, suffix1 = p1
    type2, suffix2 = p2
    yield type1, type2, suffix1, suffix2
  end
end

def primitive_operation_type(*types)
  return float64 if types.include?('Float64')
  return float32 if types.include?('Float32')

  return self.types[types.first]
end

def rw(name, restriction = nil)
  %Q(
  def #{name}=(value#{restriction ? " : #{restriction}" : ""})
    @#{name} = value
  end

  def #{name}
    @#{name}
  end
  )
end

# Extend some Ruby core classes to make it easier
# to create Crystal AST nodes.

class FalseClass
  def bool
    Crystal::BoolLiteral.new self
  end
end

class TrueClass
  def bool
    Crystal::BoolLiteral.new self
  end
end

class Fixnum
  def int32
    Crystal::NumberLiteral.new self, :i32
  end

  def int64
    Crystal::NumberLiteral.new self, :i64
  end

  def float32
    Crystal::NumberLiteral.new self.to_f, :f32
  end

  def float64
    Crystal::NumberLiteral.new self.to_f, :f64
  end
end

class Float
  def float32
    Crystal::NumberLiteral.new self, :f32
  end

  def float64
    Crystal::NumberLiteral.new self, :f64
  end
end

class String
  def var
    Crystal::Var.new self
  end

  def arg
    Crystal::Arg.new self
  end

  def call(*args)
    Crystal::Call.new nil, self, args
  end

  def ident(global = false)
    Crystal::Ident.new [self], global
  end

  def instance_var
    Crystal::InstanceVar.new self
  end

  def class_var
    Crystal::ClassVar.new self
  end

  def string
    Crystal::StringLiteral.new self
  end

  def symbol
    Crystal::SymbolLiteral.new self
  end
end

class Array
  def ident
    Ident.new self
  end

  def array
    Crystal::ArrayLiteral.new self
  end

  def array_of(type)
    Crystal::ArrayLiteral.new self, type
  end
end

class Crystal::ASTNode
  def not
    Call.new(self, :"!@")
  end

  def pointer_of
    NewGenericClass.new(Ident.new(["Pointer"], true), [self])
  end
end
