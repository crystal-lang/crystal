require "spec"

module ModuleWithLooooooooooooooooooooooooooooooooooooooooooooooongName
  def self.foo
    raise "Foo"
  end
end

describe "Exception" do
  pending "allocates enough space for backtrace frames" do
    begin
      ModuleWithLooooooooooooooooooooooooooooooooooooooooooooooongName.foo
    rescue ex
      ex.backtrace.each do |bt|
        puts bt
      end
      ex.backtrace.any? {|x| x.includes? "ModuleWithLooooooooooooooooooooooooooooooooooooooooooooooongName" }.should be_true
    end
  end

  it "unescapes linux backtrace" do
    frame = "_2A_Crystal_3A__3A_Compiler_23_compile_3C_Crystal_3A__3A_Compiler_3E__3A_Nil"
    fixed = "\u{2A}Crystal\u{3A}\u{3A}Compiler\u{23}compile\u{3C}Crystal\u{3A}\u{3A}Compiler\u{3E}\u{3A}Nil"
    Exception.unescape_linux_backtrace_frame(frame).should eq(fixed)
  end
end
