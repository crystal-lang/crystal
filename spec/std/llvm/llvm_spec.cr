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

  it ".default_target_triple" do
    triple = LLVM.default_target_triple
    {% if flag?(:darwin) %}
      triple.should match(/-apple-(darwin|macosx)/)
    {% elsif flag?(:android) %}
      triple.should match(/-android$/)
    {% elsif flag?(:linux) %}
      triple.should match(/-linux/)
    {% elsif flag?(:windows) %}
      triple.should match(/-windows-/)
    {% elsif flag?(:freebsd) %}
      triple.should match(/-freebsd/)
    {% elsif flag?(:openbsd) %}
      triple.should match(/-openbsd/)
    {% elsif flag?(:dragonfly) %}
      triple.should match(/-dragonfly/)
    {% elsif flag?(:netbsd) %}
      triple.should match(/-netbsd/)
    {% elsif flag?(:solaris) %}
      triple.should match(/-solaris$/)
    {% elsif flag?(:wasi) %}
      triple.should match(/-wasi/)
    {% else %}
      pending! "Unknown operating system"
    {% end %}
  end
end
