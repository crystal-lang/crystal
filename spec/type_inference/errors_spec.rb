require 'spec_helper'

describe 'Type inference: errors' do
  it "reports undefined local variable or method" do
    nodes = parse %(
def foo
  a = something
end

def bar
  foo
end

bar).strip

    lambda {
      type nodes
    }.should raise_error(Crystal::Exception, "
Error: undefined local variable or method 'something' in 'foo'

  a = something
      ^~~~~~~~~

in line 2: 'foo'
in line 6: 'bar'
in line 9
      ".strip)
  end
end
