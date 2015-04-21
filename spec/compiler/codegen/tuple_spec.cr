require "../../spec_helper"

describe "Code gen: tuple" do
  it "codegens tuple [0]" do
    expect(run("{1, true}[0]").to_i).to eq(1)
  end

  it "codegens tuple [1]" do
    expect(run("{1, true}[1]").to_b).to be_true
  end

  it "codegens tuple [1] (2)" do
    expect(run("{true, 3}[1]").to_i).to eq(3)
  end

  it "passed tuple to def" do
    expect(run("
      def foo(t)
        t[1]
      end

      foo({1, 2, 3})
      ").to_i).to eq(2)
  end

  it "accesses a tuple type and creates instance from it" do
    expect(run("
      struct Tuple
        def types
          T
        end
      end

      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      t = {Foo.new(1)}
      f = t.types[0].new(2)
      f.x
      ").to_i).to eq(2)
  end

  it "allows malloc pointer of tuple" do
    expect(run("
      struct Pointer
        def self.malloc(size : Int)
          malloc(size.to_u64)
        end
      end

      def foo(x : T)
        p = Pointer(T).malloc(1)
        p.value = x
        p
      end

      p = foo({1, 2})
      p.value[0] + p.value[1]
      ").to_i).to eq(3)
  end

  it "codegens tuple union (bug because union size was computed incorrectly)" do
    expect(run(%(
      require "prelude"
      x = 1 == 1 ? {1, 1, 1} : {1}
      i = 2
      x[i]
      )).to_i).to eq(1)
  end

  it "codegens tuple class" do
    expect(run(%(
      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      class Bar
      end

      foo = Foo.new(1)
      bar = Bar.new

      tuple = {foo, bar}
      tuple_class = tuple.class
      foo_class = tuple_class[0]
      foo2 = foo_class.new(2)
      foo2.x
      )).to_i).to eq(2)
  end

  it "gets length at compile time" do
    expect(run(%(
      struct Tuple
        def my_length
          {{ @length }}
        end
      end

      {1, 1}.my_length
      )).to_i).to eq(2)
  end
end
