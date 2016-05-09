require "../../spec_helper"

describe "Code gen: named tuple" do
  it "codegens tuple index" do
    run(%(
      t = {x: 42, y: 'a'}
      t[:x]
      )).to_i.should eq(42)
  end

  it "codegens tuple index another order" do
    run(%(
      t = {y: 'a', x: 42}
      t[:x]
      )).to_i.should eq(42)
  end

  it "passes named tuple to def" do
    run("
      def foo(t)
        t[:x]
      end

      foo({y: 'a', x: 42})
      ").to_i.should eq(42)
  end

  it "gets size at compile time" do
    run(%(
      struct NamedTuple
        def my_size
          {{ T.size }}
        end
      end

      {x: 10, y: 20}.my_size
      )).to_i.should eq(2)
  end

  it "gets keys at compile time (1)" do
    run(%(
      struct NamedTuple
        def keys
          {{ T.keys.map(&.stringify)[0] }}
        end
      end

      {x: 10, y: 2}.keys
      )).to_string.should eq("x")
  end

  it "gets keys at compile time (2)" do
    run(%(
      struct NamedTuple
        def keys
          {{ T.keys.map(&.stringify)[1] }}
        end
      end

      {x: 10, y: 2}.keys
      )).to_string.should eq("y")
  end

  it "doesn't crash when overload doesn't match" do
    codegen(%(
      struct NamedTuple
        def foo(other : self)
        end

        def foo(other)
        end
      end

      tup1 = {a: 1}
      tup2 = {b: 1}
      tup1.foo(tup2)
      ))
  end

  it "assigns named tuple to compatible named tuple" do
    run(%(
      ptr = Pointer({x: Int32, y: String}).malloc(1_u64)

      # Here the compiler should reoder the values to match
      # the type inside the pointer
      ptr.value = {y: "hello", x: 42}

      ptr.value[:x]
      )).to_i.should eq(42)
  end

  it "upcasts named tuple inside compatible named tuple" do
    run(%(
      def foo
        if 1 == 2
          {name: "Foo", age: 20}
        else
          # Here the compiler should reorder the values to match
          # those of the tuple above
          {age: 40, name: "Bar"}
        end
      end

      foo[:name]
      )).to_string.should eq("Bar")
  end

  it "assigns named tuple union to compatible named tuple" do
    run(%(
      tup1 = {x: 1, y: "foo"}
      tup2 = {x: 3}
      tup3 = {y: "bar", x: 42}

      ptr = Pointer(typeof(tup1, tup2, tup3)).malloc(1_u64)

      # Here the compiler should reorder the values
      # inside tup3 to match the order of tup1
      ptr.value = tup3

      ptr.value[:x]
      )).to_i.should eq(42)
  end

  it "upcasts named tuple union to compatible named tuple" do
    run(%(
      def foo
        if 1 == 2
          {x: 1, y: "foo"} || {x: 3}
        else
          {y: "bar", x: 42}
        end
      end

      foo[:x]
      )).to_i.should eq(42)
  end

  it "assigns named tuple inside union to union with compatible named tuple" do
    run(%(
      tup1 = {x: 21, y: "foo"}
      tup2 = {x: 3}

      union1 = tup1 || tup2

      tup3 = {y: "bar", x: 42}
      tup4 = {x: 4}

      union2 = tup3 || tup4

      ptr = Pointer(typeof(union1, union2)).malloc(1_u64)

      # Here the compiler should reorder the values inside
      # tup3 inside union2 to match the order of tup1
      ptr.value = union2

      ptr.value[:x]
      )).to_i.should eq(42)
  end

  it "upcasts named tuple inside union to union with compatible named tuple" do
    run(%(
      def foo
        if 1 == 2
          tup1 = {x: 21, y: "foo"}
          tup2 = {x: 3}
          union1 = tup1 || tup2
          union1
        else
          tup3 = {y: "bar", x: 42}
          tup4 = {x: 4}
          union2 = tup3 || tup4

          # Here the compiler should reorder the values inside
          # tup3 inside union2 to match the order of tup1
          union2
        end
      end

      foo[:x]
      )).to_i.should eq(42)
  end
end
