$spec_context = []
$spec_results = []
$spec_count = 0
$spec_failures = 0

def it(description)
  $spec_context << description
  $spec_success = true
  $spec_count += 1
  yield
  if $spec_success
    print '.'
  else
    print 'F'
    $spec_failures += 1
  end
  $spec_context.pop
end

def describe(description)
  $spec_context << description
  yield
  $spec_context.pop
end

def spec_results
  puts
  puts $spec_results.join "\n"
  puts "#{$spec_count} examples, #{$spec_failures} failures"
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
      $spec_results << "In #{$spec_context.join(" ")}, expected #{@value.inspect} but got #{value.inspect}"
      $spec_success = false
    end
  end
end

def eq(value)
  EqualExpectation.new value
end

def be_true
  eq(true)
end

def be_false
  eq(false)
end