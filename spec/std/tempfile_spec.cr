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
end
