require "spec"
require "tempfile"

describe Tempfile do
  it "creates and writes" do
    tempfile = Tempfile.new "foo"
    tempfile.print "Hello!"
    tempfile.close

    File.exists?(tempfile.path).should be_true
    File.read(tempfile.path).should eq("Hello!")
  end

  it "creates and deletes" do
    tempfile = Tempfile.new "foo"
    tempfile.close
    tempfile.delete

    File.exists?(tempfile.path).should be_false
  end

  it "doesn't delete on open with block" do
    tempfile = Tempfile.open("foo") do |f|
      f.print "Hello!"
    end
    File.exists?(tempfile.path).should be_true
  end

  it "creates and writes with TMPDIR environment variable" do
    old_tmpdir = ENV["TMPDIR"]?
    ENV["TMPDIR"] = "/tmp"

    begin
      tempfile = Tempfile.new "foo"
      tempfile.print "Hello!"
      tempfile.close

      File.exists?(tempfile.path).should be_true
      File.read(tempfile.path).should eq("Hello!")
    ensure
      ENV["TMPDIR"] = old_tmpdir if old_tmpdir
    end
  end

  it "is seekable" do
    tempfile = Tempfile.new "foo"
    tempfile.puts "Hello!"
    tempfile.seek(0, IO::Seek::Set)
    tempfile.tell.should eq(0)
    tempfile.pos.should eq(0)
    tempfile.gets.should eq("Hello!\n")
    tempfile.pos = 0
    tempfile.gets.should eq("Hello!\n")
    tempfile.close
  end
end
