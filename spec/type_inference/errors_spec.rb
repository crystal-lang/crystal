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

  it "reports undefined method" do
    nodes = parse "foo()"

    lambda {
      type nodes
    }.should raise_error(Crystal::Exception, /undefined method 'foo'/)
  end

  it "reports wrong number of arguments" do
    nodes = parse "def foo(x); x; end; foo"

    lambda {
      type nodes
    }.should raise_error(Crystal::Exception, /wrong number of arguments for 'foo' \(0 for 1\)/)
  end
end
