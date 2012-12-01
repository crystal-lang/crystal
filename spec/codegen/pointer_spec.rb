require 'spec_helper'

describe 'Code gen: pointer' do
  it "get pointer and value of it" do
    run('a = 1; b = ptr(a); b.value').to_i.should eq(1)
  end

  it "get pointer of instance var" do
    run(%q(
      class Foo
        def initialize(value)
          @value = value
        end

        def value_ptr
          ptr(@value)
        end
      end

      foo = Foo.new(10)
      value_ptr = foo.value_ptr
      value_ptr.value
      )).to_i.should eq(10)
  end
end