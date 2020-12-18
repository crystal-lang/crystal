require "spec"
require "llvm"

describe LLVM do
  describe ".normalize_triple" do
    it "works" do
      LLVM.normalize_triple("x86_64-apple-macos").should eq("x86_64-apple-macos")
    end

    it "substitutes unknown for empty components" do
      LLVM.normalize_triple("x86_64-linux-gnu").should eq("x86_64-unknown-linux-gnu")
    end
  end
end
