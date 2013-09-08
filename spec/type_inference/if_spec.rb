require 'spec_helper'

describe 'Type inference: if' do
  it "types an if without else" do
    assert_type('if 1 == 1; 1; end') { union_of(int32, self.nil) }
  end

  it "types an if with else of same type" do
    assert_type('if 1 == 1; 1; else; 2; end') { int32 }
  end

  it "types an if with else of different type" do
    assert_type('if 1 == 1; 1; else; 1.1; end') { union_of(int32, float64) }
  end

  it "types and if with and and assignment" do
    assert_type("
      class Number
        def abs
          self
        end
      end

      class Foo
        def coco
          @a = 1 || nil
          if (b = @a) && 1 == 1
            b.abs
          end
        end
      end

      Foo.new.coco
      ") { union_of(int32, self.nil) }
  end
end
