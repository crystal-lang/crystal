require "../../spec_helper"

describe "Type inference: NoReturn" do
  it "types call to C.exit as NoReturn" do
    assert_type("lib C; fun exit : NoReturn; end; C.exit") { no_return }
  end

  it "types raise as NoReturn" do
    assert_type("require \"prelude\"; raise \"foo\"") { no_return }
  end

  it "types union of NoReturn and something else" do
    assert_type("lib C; fun exit : NoReturn; end; 1 == 1 ? C.exit : 1") { int32 }
  end

  it "types union of NoReturns" do
    assert_type("lib C; fun exit : NoReturn; end; 1 == 2 ? C.exit : C.exit") { no_return }
  end

  it "types with no return even if code follows" do
    assert_type("lib C; fun exit : NoReturn; end; C.exit; 1") { no_return }
  end

  it "assumes if condition's type filters when else is no return" do
    assert_type("
      lib C
        fun exit : NoReturn
      end

      class Foo
        def foo
          1
        end
      end

      foo = Foo.new || nil
      C.exit unless foo

      foo.foo
    ") { int32 }
  end

  it "computes NoReturn in a lazy way inside if then (#314) (1)" do
    assert_type(%(
      require "prelude"

      a = 1
      b = 1
      x = nil

      while a < 10
        if a == 2
          b = "hello"
          x.not_nil!
        end

        x = 1
        a += 1
      end

      b
      )) { union_of(int32, string) }
  end

  it "computes NoReturn in a lazy way inside if then (#314) (2)" do
    assert_type(%(
      require "prelude"

      a = 1
      b = 1
      x = nil

      while a < 10
        if a == 2
          b = "hello"
          x.not_nil!
        end

        a += 1
      end

      b
      )) { int32 }
  end

  it "computes NoReturn in a lazy way inside if then (#314) (3)" do
    assert_type(%(
      require "prelude"

      a = 1
      c = nil
      x = nil

      while a < 10
        if a == 2
          b = "hello"
          x.not_nil!
        end

        if b
          c = b
        end

        x = 1
        a += 1
      end

      c
      )) { nilable(string) }
  end

  it "computes NoReturn in a lazy way inside if then (#314) (4)" do
    assert_type(%(
      require "prelude"

      a = 1
      c = nil
      x = nil

      while a < 10
        if a == 2
          b = "hello"
          x.not_nil!
        end

        if b
          c = b
        end

        a += 1
      end

      c
      )) { |mod| mod.nil }
  end

  it "computes NoReturn in a lazy way inside if then (#314) (5)" do
    assert_error  %(
      require "prelude"

      a = 1
      x = nil

      while a < 10
        if a == 1
          x.not_nil!
        else
          b = "hello"
        end

        b.length

        b = nil

        x = 1
        a += 1
      end
      ),
      "undefined method 'length' for Nil"
  end

  it "computes NoReturn in a lazy way inside if else (#314) (1)" do
    assert_type(%(
      require "prelude"

      a = 1
      b = 1
      x = nil

      while a < 10
        if a == 2
        else
          b = "hello"
          x.not_nil!
        end

        x = 1
        a += 1
      end

      b
      )) { union_of(int32, string) }
  end

  it "computes NoReturn in a lazy way inside if else (#314) (2)" do
    assert_type(%(
      require "prelude"

      a = 1
      b = 1
      x = nil

      while a < 10
        if a == 2
        else
          b = "hello"
          x.not_nil!
        end

        a += 1
      end

      b
      )) { int32 }
  end

  it "computes NoReturn in a lazy way inside if else (#314) (3)" do
    assert_type(%(
      require "prelude"

      a = 1
      c = nil
      x = nil

      while a < 10
        if a == 2
        else
          b = "hello"
          x.not_nil!
        end

        if b
          c = b
        end

        x = 1
        a += 1
      end

      c
      )) { nilable(string) }
  end

  it "computes NoReturn in a lazy way inside if else (#314) (4)" do
    assert_type(%(
      require "prelude"

      a = 1
      c = nil
      x = nil

      while a < 10
        if a == 2
        else
          b = "hello"
          x.not_nil!
        end

        if b
          c = b
        end

        a += 1
      end

      c
      )) { |mod| mod.nil }
  end

  it "computes NoReturn in a lazy way inside if else (#314) (5)" do
    assert_error  %(
      require "prelude"

      a = 1
      x = nil

      while a < 10
        if a == 1
          b = "hello"
        else
          x.not_nil!
        end

        b.length

        b = nil

        x = 1
        a += 1
      end
      ),
      "undefined method 'length' for Nil"
  end
end
