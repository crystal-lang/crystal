require 'spec_helper'

describe 'Type inference: module' do
  it "includes module in a class" do
    assert_type("module Foo; def foo; 1; end; end; class Bar; include Foo; end; Bar.new.foo") { int }
  end

  it "includes module in a module" do
    assert_type(%q(
      module A
        def foo
          1
        end
      end

      module B
        include A
      end

      class X
        include B
      end

      X.new.foo
      )) { int }
  end

  it "finds in module when included" do
    assert_type(%q(
      module A
        class B
          def foo; 1; end
        end
      end

      include A

      B.new.foo
    )) { int }
  end
end
