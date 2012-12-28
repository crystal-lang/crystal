$spec_context = []

def it(description)
  $spec_context << description
  yield
  $spec_context.pop
end

def describe(description)
  $spec_context << description
  yield
  $spec_context.pop
end

class Object
  def should(expectation)
    expectation.match self
  end
end

class EqualExpectation
  def initialize(value)
    @value = value
  end

  def match(value)
    unless value == @value
      puts "In #{$spec_context.join(" ")}, expected #{@value.inspect} but got #{value.inspect}"
    end
  end
end

def eq(value)
  EqualExpectation.new value
end