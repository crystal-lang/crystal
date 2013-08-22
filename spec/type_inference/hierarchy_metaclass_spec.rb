require 'spec_helper'

describe 'Type inference: hierarchy metaclass' do
  it "types hierarchy metaclass" do
    assert_type(%q(
      class Foo
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new
      f.class
    )) { types["Foo"].hierarchy_type.metaclass }
  end

  it "types hierarchy metaclass method" do
    assert_type(%q(
      class Foo
        def self.foo
          1
        end
      end

      class Bar < Foo
        def self.foo
          1.5
        end
      end

      f = Foo.new || Bar.new
      f.class.foo
    )) { union_of(int32, float64) }
  end
end
