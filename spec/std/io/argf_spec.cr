require "spec"

describe IO::ARGF do
  it "reads from STDIN if ARGV isn't specified" do
    argv = [] of String
    stdin = StringIO.new("hello")

    argf = IO::ARGF.new argv, stdin
    argf.path.should eq("-")
    argf.read.should eq("hello")
    argf.read_byte.should be_nil
  end

  it "reads from ARGV if specified" do
    path1 = "#{__DIR__}/../data/argf_test_file_1.txt"
    path2 = "#{__DIR__}/../data/argf_test_file_2.txt"
    stdin = StringIO.new("")
    argv = [path1, path2]

    argf = IO::ARGF.new argv, stdin
    argf.path.should eq(path1)
    argv.should eq([path1, path2])

    str = argf.read(5)
    str.should eq("12345")

    argv.should eq([path2])

    str = argf.read
    str.should eq("\n67890\n")

    argv.empty?.should be_true

    argf.read_byte.should be_nil

    argv << path1
    str = argf.read(5)
    str.should eq("12345")
  end
end
