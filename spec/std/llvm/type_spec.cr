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
end
