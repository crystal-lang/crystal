require "../../spec_helper"

describe "Normalize: proc pointer" do
  it "normalizes proc pointer without object" do
    assert_expand "->foo", <<-CRYSTAL
      -> do
        foo
      end
      CRYSTAL
  end

  it "normalizes proc pointer with parameters, without object" do
    assert_expand "->foo(Int32, String)", <<-CRYSTAL
      ->(__temp_1 : Int32, __temp_2 : String) do
        foo(__temp_1, __temp_2)
      end
      CRYSTAL
  end

  it "normalizes proc pointer of global call" do
    assert_expand "->::foo(Int32)", <<-CRYSTAL
      ->(__temp_1 : Int32) do
        ::foo(__temp_1)
      end
      CRYSTAL
  end

  it "normalizes proc pointer with const receiver" do
    assert_expand "->Foo.foo(Int32)", <<-CRYSTAL
      ->(__temp_1 : Int32) do
        Foo.foo(__temp_1)
      end
      CRYSTAL
  end

  it "normalizes proc pointer with global const receiver" do
    assert_expand "->::Foo.foo(Int32)", <<-CRYSTAL
      ->(__temp_1 : Int32) do
        ::Foo.foo(__temp_1)
      end
      CRYSTAL
  end

  it "normalizes proc pointer with variable receiver" do
    assert_expand_second "foo = 1; ->foo.bar(Int32)", <<-CRYSTAL
      __temp_1 = foo
      ->(__temp_2 : Int32) do
        __temp_1.bar(__temp_2)
      end
      CRYSTAL
  end

  it "normalizes proc pointer with ivar receiver" do
    assert_expand "->@foo.bar(Int32)", <<-CRYSTAL
      __temp_1 = @foo
      ->(__temp_2 : Int32) do
        __temp_1.bar(__temp_2)
      end
      CRYSTAL
  end

  it "normalizes proc pointer with cvar receiver" do
    assert_expand "->@@foo.bar(Int32)", <<-CRYSTAL
      __temp_1 = @@foo
      ->(__temp_2 : Int32) do
        __temp_1.bar(__temp_2)
      end
      CRYSTAL
  end
end
