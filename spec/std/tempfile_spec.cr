require "spec"
require "tempfile"

describe Tempfile do
  it "creates and writes" do
    tempfile = Tempfile.new "foo"
    tempfile.print "Hello!"
    tempfile.close

    expect(File.exists?(tempfile.path)).to be_true
    expect(File.read(tempfile.path)).to eq("Hello!")
  end

  it "creates and deletes" do
    tempfile = Tempfile.new "foo"
    tempfile.close
    tempfile.delete

    expect(File.exists?(tempfile.path)).to be_false
  end

  it "doesn't delete on open with block" do
    tempfile = Tempfile.open("foo") do |f|
      f.print "Hello!"
    end
    expect(File.exists?(tempfile.path)).to be_true
  end

  it "creates and writes with TMPDIR environment variable" do
    old_tmpdir = ENV["TMPDIR"]?
    ENV["TMPDIR"] = "/tmp"

    begin
      tempfile = Tempfile.new "foo"
      tempfile.print "Hello!"
      tempfile.close

      expect(File.exists?(tempfile.path)).to be_true
      expect(File.read(tempfile.path)).to eq("Hello!")
    ensure
      ENV["TMPDIR"] = old_tmpdir if old_tmpdir
    end
  end
end
