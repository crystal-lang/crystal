require "../spec_helper"

describe IO::ARGF do
  it "reads from STDIN if ARGV isn't specified" do
    argv = [] of String
    stdin = IO::Memory.new("hello")

    argf = IO::ARGF.new argv, stdin
    argf.path.should eq("-")
    argf.gets_to_end.should eq("hello")
    argf.read_byte.should be_nil
  end

  it "reads from ARGV if specified" do
    path1 = datapath("argf_test_file_1.txt")
    path2 = datapath("argf_test_file_2.txt")
    stdin = IO::Memory.new("")
    argv = [path1, path2]

    argf = IO::ARGF.new argv, stdin
    argf.path.should eq(path1)
    argv.should eq([path1, path2])

    str = argf.gets(5)
    str.should eq("12345")

    argv.should eq([path2])

    str = argf.gets_to_end
    str.should eq("\n67890\n")

    argv.should be_empty

    argf.read_byte.should be_nil

    argv << path1
    str = argf.gets(5)
    str.should eq("12345")
  end

  it "reads when is more data left to read" do
    argf = IO::ARGF.new [datapath("argf_test_file_3.xml")], IO::Memory.new
    argf.read(Bytes.new(4))
    buf = Bytes.new(4096)
    z = argf.read(buf)
    z = argf.read(buf)
    z = argf.read(buf)
    z = argf.read(buf)
    z.should_not eq 0
    String.new(buf[0...z]).should_not be_empty
  end

  describe "gets" do
    it "reads from STDIN if ARGV isn't specified" do
      argv = [] of String
      stdin = IO::Memory.new("hello\nworld\n")

      argf = IO::ARGF.new argv, stdin
      argf.gets.should eq("hello")
      argf.gets.should eq("world")
      argf.gets.should be_nil
    end

    it "reads from STDIN if ARGV isn't specified, chomp = false" do
      argv = [] of String
      stdin = IO::Memory.new("hello\nworld\n")

      argf = IO::ARGF.new argv, stdin
      argf.gets(chomp: false).should eq("hello\n")
      argf.gets(chomp: false).should eq("world\n")
      argf.gets(chomp: false).should be_nil
    end

    it "reads from ARGV if specified" do
      path1 = datapath("argf_test_file_1.txt")
      path2 = datapath("argf_test_file_2.txt")
      stdin = IO::Memory.new("")
      argv = [path1, path2]

      argf = IO::ARGF.new argv, stdin
      argv.should eq([path1, path2])

      argf.gets(chomp: false).should eq("12345\n")
      argv.should eq([path2])

      argf.gets(chomp: false).should eq("67890\n")
      argv.should be_empty

      argf.gets(chomp: false).should be_nil

      argv << path1
      str = argf.gets(chomp: false)
      str.should eq("12345\n")
    end
  end

  describe "peek" do
    it "peeks from STDIN if ARGV isn't specified" do
      argv = [] of String
      stdin = IO::Memory.new("1234")

      argf = IO::ARGF.new argv, stdin
      argf.peek.should eq("1234".to_slice)

      argf.gets_to_end.should eq("1234")
    end

    it "peeks from ARGV if specified" do
      path1 = datapath("argf_test_file_1.txt")
      path2 = datapath("argf_test_file_2.txt")
      stdin = IO::Memory.new("")
      argv = [path1, path2]

      argf = IO::ARGF.new argv, stdin
      argf.peek.should eq("12345\n".to_slice)

      argf.read_string(6)
      argf.read_byte

      argf.peek.should eq("7890\n".to_slice)
    end
  end
end
