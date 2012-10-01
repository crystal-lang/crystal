require 'bundler/setup'
require 'pry'
require 'pry-nav'
require(File.expand_path("../../lib/crystal",  __FILE__))

include Crystal

# Escaped regexp
def regex(str)
  /#{Regexp.escape(str)}/
end

def assert_type(str, &block)
  input = parse str
  mod = infer_type input
  expected_type = mod.instance_eval &block
  expected_type.should_not be_nil
  input.last.type.should eq(expected_type)
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
    Crystal::Bool.new self
  end
end

class TrueClass
  def bool
    Crystal::Bool.new self
  end
end

class Fixnum
  def int
    Crystal::Int.new self
  end

  def float
    Crystal::Float.new self.to_f
  end
end

class Float
  def float
    Crystal::Float.new self
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