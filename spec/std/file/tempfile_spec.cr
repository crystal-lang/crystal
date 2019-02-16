require "../spec_helper"
require "../../support/errno"

describe File do
  describe ".tempname" do
    it "creates a path without creating the file" do
      path = File.tempname

      File.exists?(path).should be_false
      File.dirname(path).should eq Dir.tempdir
    end

    it "accepts single suffix argument" do
      path = File.tempname ".bar"

      File.exists?(path).should be_false
      File.dirname(path).should eq Dir.tempdir
      File.extname(path).should eq(".bar")
    end

    it "accepts prefix and suffix arguments" do
      path = File.tempname "foo", ".bar"

      File.exists?(path).should be_false
      File.dirname(path).should eq Dir.tempdir
      File.extname(path).should eq(".bar")
      File.basename(path).starts_with?("foo").should be_true
    end

    it "accepts prefix with separator" do
      path = File.tempname "foo/", nil
      File.dirname(path).should eq File.join(Dir.tempdir, "foo")
      File.basename(path).starts_with?("foo").should be_false
    end

    it "accepts dir argument" do
      path = File.tempname(dir: "foo")
      File.dirname(path).should eq("foo")
    end
  end

  describe ".tempfile" do
    it "creates and writes" do
      tempfile = File.tempfile
      tempfile.print "Hello!"
      tempfile.close

      File.exists?(tempfile.path).should be_true
      File.read(tempfile.path).should eq("Hello!")
    ensure
      tempfile.try &.delete
    end

    it "accepts single suffix argument" do
      tempfile = File.tempfile ".bar"
      tempfile.print "Hello!"
      tempfile.close

      File.extname(tempfile.path).should eq(".bar")

      File.exists?(tempfile.path).should be_true
      File.read(tempfile.path).should eq("Hello!")
    ensure
      tempfile.try &.delete
    end

    it "accepts prefix and suffix arguments" do
      tempfile = File.tempfile "foo", ".bar"
      tempfile.print "Hello!"
      tempfile.close

      File.extname(tempfile.path).should eq(".bar")
      File.basename(tempfile.path).starts_with?("foo").should be_true

      File.exists?(tempfile.path).should be_true
      File.read(tempfile.path).should eq("Hello!")
    ensure
      tempfile.try &.delete
    end

    it "accepts dir argument" do
      file = File.tempfile(dir: datapath)
      File.dirname(file.path).should eq(datapath)
    ensure
      file.try &.delete
    end

    it "fails in unwritable folder" do
      expect_raises_errno(Errno::ENOENT, "mkstemp: '#{datapath("non-existing-folder")}/") do
        File.tempfile dir: datapath("non-existing-folder")
      end
    end

    describe "with block" do
      it "closes file" do
        filepath = nil
        tempfile = File.tempfile do |tempfile|
          filepath = tempfile.path
        end
        tempfile.path.should eq filepath
        tempfile.closed?.should be_true

        filepath = filepath.not_nil!
        File.exists?(filepath).should be_true
      ensure
        File.delete(filepath) if filepath
      end

      it "accepts single suffix argument" do
        tempfile = File.tempfile(".bar") do |tempfile|
          File.exists?(tempfile.path).should be_true
          tempfile.closed?.should be_false
        end
        tempfile.closed?.should be_true

        File.extname(tempfile.path).should eq(".bar")

        File.exists?(tempfile.path).should be_true
      ensure
        File.delete(tempfile.path) if tempfile
      end

      it "accepts prefix and suffix arguments" do
        tempfile = File.tempfile("foo", ".bar") do |tempfile|
          File.exists?(tempfile.path).should be_true
          tempfile.closed?.should be_false
        end
        tempfile.closed?.should be_true

        File.extname(tempfile.path).should eq(".bar")
        File.basename(tempfile.path).starts_with?("foo").should be_true

        File.exists?(tempfile.path).should be_true
      ensure
        File.delete(tempfile.path) if tempfile
      end

      it "accepts dir argument" do
        tempfile = File.tempfile(dir: datapath) do |tempfile|
        end
        File.dirname(tempfile.path).should eq(datapath)
      ensure
        File.delete(tempfile.path) if tempfile
      end
    end
  end
end
