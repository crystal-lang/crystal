require 'spec_helper'

describe 'Type inference: nil' do
  it "types nil" do
    assert_type('nil') { self.nil }
  end

  it "can call a fun with nil for pointer" do
    assert_type(%q(lib A; fun a(c : Char*) : Int; end; A.a(nil))) { int }
  end

  it "can call a fun with nil for typedef pointer" do
    assert_type(%q(lib A; type Foo : Char*; fun a(c : Foo) : Int; end; A.a(nil))) { int }
  end

  it "marks instance variables as nil but doesn't explode on macros" do
    assert_type(%q(
      require "prelude"

      class Foo
        def initialize
          @var = [1]
          @var.last
        end

        attr_reader :var
      end

      f = Foo.new
      f.var.last
    )) { union_of(int) }
  end
end
