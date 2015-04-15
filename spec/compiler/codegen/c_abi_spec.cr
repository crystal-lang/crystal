require "../../spec_helper"

# These specs just test that building code that passes and
# returns structs generates valid LLVM code
describe "Code gen: C ABI" do
  it "passes struct less than 64 bits as { i64 }" do
    mod = build(%(
      lib LibC
        struct Struct
          x : Int8
          y : Int16
        end

        fun foo(s : Struct)
      end

      s = LibC::Struct.new
      LibC.foo(s)
      )).first_value
    str = mod.to_s
    str.should contain("call void @foo({ i64 }")
    str.should contain("declare void @foo({ i64 })")
  end

  it "passes struct between 64 and 128 bits as { i64, i64 }" do
    mod = build(%(
      lib LibC
        struct Struct
          x : Int64
          y : Int16
        end

        fun foo(s : Struct)
      end

      s = LibC::Struct.new
      LibC.foo(s)
      )).first_value
    str = mod.to_s
    str.should contain("call void @foo({ i64, i64 }")
    str.should contain("declare void @foo({ i64, i64 })")
  end

  it "passes struct bigger than128 bits with byval" do
    mod = build(%(
      lib LibC
        struct Struct
          x : Int64
          y : Int64
          z : Int8
        end

        fun foo(s : Struct)
      end

      s = LibC::Struct.new
      LibC.foo(s)
      )).first_value
    str = mod.to_s
    str.scan(/byval/).length.should eq(2)
  end

  it "returns struct less than 64 bits as { i64 }" do
    mod = build(%(
      lib LibC
        struct Struct
          x : Int8
          y : Int16
        end

        fun foo : Struct
      end

      str = LibC.foo
      )).first_value
    str = mod.to_s
    str.should contain("call { i64 } @foo()")
    str.should contain("declare { i64 } @foo()")
  end

  it "returns struct between 64 and 128 bits as { i64, i64 }" do
    mod = build(%(
      lib LibC
        struct Struct
          x : Int64
          y : Int16
        end

        fun foo : Struct
      end

      str = LibC.foo
      )).first_value
    str = mod.to_s
    str.should contain("call { i64, i64 } @foo()")
    str.should contain("declare { i64, i64 } @foo()")
  end

  it "returns struct bigger than 128 bits with sret" do
    mod = build(%(
      lib LibC
        struct Struct
          x : Int64
          y : Int64
          z : Int8
        end

        fun foo(w : Int32) : Struct
      end

      str = LibC.foo(1)
      )).first_value
    str = mod.to_s
    str.scan(/sret/).length.should eq(2)
    str.should contain("sret, i32") # sret goes as first argument
  end
end
