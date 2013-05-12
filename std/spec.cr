$spec_context = [] of String
$spec_results = [] of String
$spec_count = 0
$spec_failures = 0
$spec_manual_results = false

def it(description)
  $spec_context << description
  assert { yield }
  $spec_context.pop
end

def assert
  $spec_success = true
  $spec_count += 1
  yield
  if $spec_success
    print '.'
  else
    print 'F'
    $spec_failures += 1
  end
end

def fail(msg)
  $spec_results << "In #{$spec_context.join(" ")}, #{msg}"
  $spec_success = false
end

def describe(description)
  $spec_context << description
  yield
  $spec_context.pop
  spec_results unless $spec_manual_results || !$spec_context.empty?
end

def spec_results
  puts
  puts $spec_results.join "\n"
  puts "#{$spec_count} examples, #{$spec_failures} failures"
end

class Object
  def should(expectation)
    unless expectation.match self
      fail expectation.failure_message
    end
  end

  def should_not(expectation)
    if expectation.match self
      fail expectation.negative_failure_message
    end
  end
end

class EqualExpectation
  def initialize(value)
    @value = value
  end

  def match(value)
    @target = value
    value == @value
  end

  def failure_message
    "expected #{@value.inspect} but got #{@target.inspect}"
  end

  def negative_failure_message
    "didn't expect #{@value.inspect} but got #{@target.inspect}"
  end
end

def eq(value)
  EqualExpectation.new value
end

def be_true
  eq true
end

def be_false
  eq false
end

def be_nil
  eq nil
end
