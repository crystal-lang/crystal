require "spec"
require "tempfile"

describe Tempfile do
  describe "tempname" do
    it "creates a path without creating the file" do
      path = Tempfile.tempname

      File.exists?(path).should be_false
    end

    it "has the given extension" do
      path = Tempfile.tempname ".sock"

      File.extname(path).should eq(".sock")
    end
  end

  it "creates and writes" do
    tempfile = Tempfile.new "foo"
    tempfile.print "Hello!"
    tempfile.close

    File.exists?(tempfile.path).should be_true
    File.read(tempfile.path).should eq("Hello!")
  ensure
    File.delete(tempfile.path) if tempfile
  end

  it "has given extension if passed to constructor" do
    tempfile = Tempfile.new "foo", ".pdf"
    File.extname(tempfile.path).should eq(".pdf")
  end

  it "creates and deletes" do
    tempfile = Tempfile.new "foo"
    tempfile.close
    tempfile.delete

    File.exists?(tempfile.path).should be_false
  ensure
    File.delete(tempfile.path) if tempfile && File.exists?(tempfile.path)
  end

  it "doesn't delete on open with block" do
    tempfile = Tempfile.open("foo") do |f|
      f.print "Hello!"
    end
    File.exists?(tempfile.path).should be_true
  ensure
    File.delete(tempfile.path) if tempfile
  end

  it "has given extension if passed to open" do
    tempfile = Tempfile.open("foo", ".pdf") { |f| }
    File.extname(tempfile.path).should eq(".pdf")
  ensure
    File.delete(tempfile.path) if tempfile
  end

  it "creates and writes with TMPDIR environment variable" do
    old_tmpdir = ENV["TMPDIR"]?
    ENV["TMPDIR"] = "/tmp"

    tempfile = Tempfile.new "foo"
    tempfile.print "Hello!"
    tempfile.close

    File.exists?(tempfile.path).should be_true
    File.read(tempfile.path).should eq("Hello!")
  ensure
    ENV["TMPDIR"] = old_tmpdir if old_tmpdir
    File.delete(tempfile.path) if tempfile
  end

  it "is seekable" do
    tempfile = Tempfile.new "foo"
    tempfile.puts "Hello!"
    tempfile.seek(0, IO::Seek::Set)
    tempfile.tell.should eq(0)
    tempfile.pos.should eq(0)
    tempfile.gets(chomp: false).should eq("Hello!\n")
    tempfile.pos = 0
    tempfile.gets(chomp: false).should eq("Hello!\n")
    tempfile.close
  ensure
    File.delete(tempfile.path) if tempfile
  end

  it "returns default directory for tempfiles" do
    old_tmpdir = ENV["TMPDIR"]?
    ENV.delete("TMPDIR")
    Tempfile.dirname.should eq("/tmp")
  ensure
    ENV["TMPDIR"] = old_tmpdir if old_tmpdir
  end

  it "returns configure directory for tempfiles" do
    old_tmpdir = ENV["TMPDIR"]?
    ENV["TMPDIR"] = "/my/tmp"
    Tempfile.dirname.should eq("/my/tmp")
  ensure
    ENV["TMPDIR"] = old_tmpdir if old_tmpdir
  end
end
