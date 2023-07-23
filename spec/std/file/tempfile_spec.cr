require "../spec_helper"
require "../../support/tempfile"

private class TestRNG(T)
  include Random

  def initialize(@data : Array(T))
    @i = 0
  end

  def next_u : T
    i = @i
    @i = (i + 1) % @data.size
    @data[i]
  end

  def reset
    @i = 0
  end
end

private def normalize_permissions(permissions, *, directory)
  {% if flag?(:win32) %}
    normalized_permissions = 0o444
    normalized_permissions |= 0o222 if permissions.bits_set?(0o200)
    normalized_permissions |= 0o111 if directory
    File::Permissions.new(normalized_permissions)
  {% else %}
    File::Permissions.new(permissions)
  {% end %}
end

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
      File.basename(path).should start_with("foo")
    end

    it "accepts prefix with separator" do
      path = File.tempname "foo/", nil
      File.dirname(path).should eq File.join(Dir.tempdir, "foo")
      File.basename(path).should_not start_with("foo")
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
      tempfile.info.permissions.should eq normalize_permissions(0o600, directory: false)
      tempfile.close

      File.exists?(tempfile.path).should be_true
      File.read(tempfile.path).should eq("Hello!")
    ensure
      tempfile.try &.delete
    end

    it "accepts single suffix argument" do
      tempfile = File.tempfile ".bar"
      tempfile.print "Hello!"
      tempfile.info.permissions.should eq normalize_permissions(0o600, directory: false)
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
      tempfile.info.permissions.should eq normalize_permissions(0o600, directory: false)
      tempfile.close

      File.extname(tempfile.path).should eq(".bar")
      File.basename(tempfile.path).should start_with("foo")

      File.exists?(tempfile.path).should be_true
      File.read(tempfile.path).should eq("Hello!")
    ensure
      tempfile.try &.delete
    end

    it "accepts dir argument" do
      file = File.tempfile(dir: datapath)
      File.dirname(file.path).should eq(datapath)
      file.close
    ensure
      file.try &.delete
    end

    it "fails in nonwriteable folder" do
      err_directory = (datapath("non-existing-folder") + Path::SEPARATORS[0]).inspect_unquoted
      expect_raises(File::NotFoundError, "Error creating temporary file: '#{err_directory}") do
        File.tempfile dir: datapath("non-existing-folder")
      end
    end

    it "rejects null byte" do
      expect_raises(ArgumentError, "String contains null byte") do
        File.tempfile("foo\0")
      end
      expect_raises(ArgumentError, "String contains null byte") do
        File.tempfile("foo", "bar\0")
      end
      expect_raises(ArgumentError, "String contains null byte") do
        File.tempfile("foo", "bar", dir: "baz\0")
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
        File.basename(tempfile.path).should start_with("foo")

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

describe Crystal::System::File do
  describe ".mktemp" do
    it "creates random file name" do
      with_tempfile "random-path" do |tempdir|
        Dir.mkdir tempdir
        fd, path = Crystal::System::File.mktemp("A", "Z", dir: tempdir, random: TestRNG.new([7, 8, 9, 10, 11, 12, 13, 14]))
        path.should eq Path[tempdir, "A789abcdeZ"].to_s
      ensure
        File.from_fd(path, fd).close if fd && path
      end
    end

    it "retries when file exists" do
      with_tempfile "retry" do |tempdir|
        Dir.mkdir tempdir
        existing_path = Path[tempdir, "A789abcdeZ"]
        File.touch existing_path
        fd, path = Crystal::System::File.mktemp("A", "Z", dir: tempdir, random: TestRNG.new([7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]))
        path.should eq File.join(tempdir, "AfghijklmZ")
      ensure
        File.from_fd(path, fd).close if fd && path
      end
    end

    it "raises when no valid path is found" do
      with_tempfile "random-path" do |tempdir|
        Dir.mkdir tempdir
        File.touch Path[tempdir, "A789abcdeZ"]
        expect_raises(File::AlreadyExistsError, "Error creating temporary file") do
          fd, path = Crystal::System::File.mktemp("A", "Z", dir: tempdir, random: TestRNG.new([7, 8, 9, 10, 11, 12, 13, 14]))
        ensure
          File.from_fd(path, fd).close if fd && path
        end
      end
    end
  end
end
