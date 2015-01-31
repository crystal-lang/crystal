require "../../spec_helper"

describe "Type inference: c union" do
  it "types c union" do
    result = assert_type("lib LibFoo; union Bar; x : Int32; y : Float64; end; end; LibFoo::Bar") { types["LibFoo"].types["Bar"].metaclass }
    mod = result.program
    bar = mod.types["LibFoo"].types["Bar"] as CUnionType
    bar.vars["x"].type.should eq(mod.int32)
    bar.vars["y"].type.should eq(mod.float64)
  end

  it "types Union#new" do
    assert_type("lib LibFoo; union Bar; x : Int32; y : Float64; end; end; LibFoo::Bar.new") do
      types["LibFoo"].types["Bar"]
    end
  end

  it "types union setter" do
    assert_type("lib LibFoo; union Bar; x : Int32; y : Float64; end; end; bar = LibFoo::Bar.new; bar.x = 1") { int32 }
  end

  it "types union getter" do
    assert_type("lib LibFoo; union Bar; x : Int32; y : Float64; end; end; bar = LibFoo::Bar.new; bar.x") { int32 }
  end

  it "types union setter via pointer" do
    assert_type("lib LibFoo; union Bar; x : Int32; y : Float64; end; end; bar = Pointer(LibFoo::Bar).malloc(1_u64); bar.value.x = 1") { int32 }
  end

  it "types union getter via pointer" do
    assert_type("lib LibFoo; union Bar; x : Int32; y : Float64; end; end; bar = Pointer(LibFoo::Bar).malloc(1_u64); bar.value.x") { int32 }
  end

  it "errors if setting closure" do
    assert_error %(
      lib LibFoo
        union Bar
          x : ->
        end
      end

      a = 1

      bar = LibFoo::Bar.new
      bar.x = -> { a }
      ),
      "can't set closure as C union member"
  end
end
