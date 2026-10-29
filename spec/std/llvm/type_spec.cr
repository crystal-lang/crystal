require "spec"
require "llvm"

describe LLVM::Type do
  describe ".const_int" do
    it "support Int64" do
      ctx = LLVM::Context.new
      ctx.int(64).const_int(Int64::MAX).to_s.should eq("i64 9223372036854775807")
    end

    it "support Int128" do
      ctx = LLVM::Context.new
      ctx.int(128).const_int(Int128::MAX).to_s.should eq("i128 170141183460469231731687303715884105727")
    end
  end

  describe "#global_value_type" do
    it "gets the type of a global variable" do
      cxt = LLVM::Context.new
      mod = cxt.new_module("mod")
      var = mod.globals.add(cxt.double, "foo")
      ty = var.global_value_type
      ty.kind.should eq(LLVM::Type::Kind::Double)
    end

    it "gets the type of a function" do
      cxt = LLVM::Context.new
      mod = cxt.new_module("mod")
      fn = mod.functions.add("foo", LLVM::Type.function([cxt.float], cxt.void))
      ty = fn.global_value_type
      ty.params_size.should eq(1)
      ty.params_types[0].kind.should eq(LLVM::Type::Kind::Float)
      ty.return_type.kind.should eq(LLVM::Type::Kind::Void)
      ty.varargs?.should be_false

      fn.return_type.kind.should eq(LLVM::Type::Kind::Void)
      fn.varargs?.should be_false
    end
  end
end
