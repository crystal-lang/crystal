require 'bundler/setup'
require 'pry'
require 'pry-nav'
require(File.expand_path("../../lib/crystal",  __FILE__))

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.filter_run_excluding :integration
end

include Crystal

# Escaped regexp
def regex(str)
  /#{Regexp.escape(str)}/
end

def assert_type(str, &block)
  input = parse str
  mod = infer_type input
  expected_type = mod.instance_eval &block
  if input.is_a?(Expressions)
    input.last.type.should eq(expected_type)
  else
    input.type.should eq(expected_type)
  end
end

def rw(name)
  %Q(
  def #{name}=(value)
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
  def int
    Crystal::IntLiteral.new self
  end

  def long
    Crystal::LongLiteral.new self
  end

  def float
    Crystal::FloatLiteral.new self.to_f
  end
end

class Float
  def float
    Crystal::FloatLiteral.new self
  end
end

class String
  def var
    Crystal::Var.new self
  end

  def call(*args)
    Crystal::Call.new nil, self, args
  end

  def const
    Crystal::Const.new self
  end

  def instance_var
    Crystal::InstanceVar.new self
  end

  def string
    Crystal::StringLiteral.new self
  end
end

class ::Array
  def array
    Crystal::Array.new self
  end
end

class Crystal::ObjectType
  def with_var(name, type)
    @instance_vars[name] = Var.new(name, type)
    self
  end
end

class Crystal::StaticArrayType
  def self.of(type)
    array = new
    array.element_type_var.type = type
    array
  end
end

class Crystal::ASTNode
  def not
    Call.new(self, :"!@")
  end
end