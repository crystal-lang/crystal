require "spec"

describe "Dir" do
  it "tests exists? on existing directory" do
    Dir.exists?(File.join([__DIR__, "../"])).should be_true
  end

  it "tests exists? on existing file" do
    Dir.exists?(__FILE__).should be_false
  end

  it "tests exists? on nonexistent directory" do
    Dir.exists?(File.join([__DIR__, "/foo/bar/"])).should be_false
  end

  it "tests mkdir and rmdir with a new path" do
    path = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    Dir.mkdir(path, 0700).should eq(0)
    Dir.exists?(path).should be_true
    Dir.rmdir(path).should eq(0)
    Dir.exists?(path).should be_false
  end

  it "tests mkdir with an existing path" do
    expect_raises Errno::EEXIST do
      Dir.mkdir(__DIR__, 0700)
    end
  end

  it "tests mkdir_p with a new path" do
    path = "/tmp/crystal_mkdir_ptest_#{Process.pid}/"
    Dir.mkdir_p(path).should eq(0)
    Dir.exists?(path).should be_true
    path = File.join({path, "a", "b", "c"})
    Dir.mkdir_p(path).should eq(0)
    Dir.exists?(path).should be_true
  end

  it "tests mkdir_p with an existing path" do
    Dir.mkdir_p(__DIR__).should eq(0)
    expect_raises Errno::EEXIST do
      Dir.mkdir_p(__FILE__)
    end
  end

  it "tests rmdir with an nonexistent path" do
    expect_raises Errno::ENOENT do
      Dir.rmdir("/tmp/crystal_mkdir_test_#{Process.pid}/")
    end
  end

  it "tests rmdir with a path that cannot be removed" do
    expect_raises Errno::ENOTEMPTY do
      Dir.rmdir(__DIR__)
    end
  end

  it "tests glob with a single pattern" do
    result = Dir["#{__DIR__}/*.cr"]
    Dir.foreach(__DIR__) do |file|
      next unless file.ends_with?(".cr")

      result.includes?(File.join(__DIR__, file)).should be_true
    end
  end

  it "tests glob with multiple patterns" do
    result = Dir["#{__DIR__}/*.cr", "#{__DIR__}/{io,html}/*.cr"]

    {__DIR__, "#{__DIR__}/io", "#{__DIR__}/html"}.each do |dir|
      Dir.foreach(dir) do |file|
        next unless file.ends_with?(".cr")
        result.includes?(File.join(dir, file)).should be_true
      end
    end
  end

  it "tests glob with a single pattern with block" do
    result = [] of String
    Dir.glob("#{__DIR__}/*.cr") do |filename|
      result << filename
    end

    Dir.foreach(__DIR__) do |file|
      next unless file.ends_with?(".cr")

      result.includes?(File.join(__DIR__, file)).should be_true
    end
  end

  describe "chdir" do
    it "should work" do
      cwd = Dir.working_directory
      Dir.chdir("..")
      Dir.working_directory.should_not eq(cwd)
      Dir.cd(cwd)
      Dir.working_directory.should eq(cwd)
    end

    it "raises" do
      expect_raises do
        Dir.chdir("/nope")
      end
    end

    it "accepts a block" do
      cwd = Dir.working_directory

      Dir.chdir("..") do
        Dir.working_directory.should_not eq(cwd)
      end

      Dir.working_directory.should eq(cwd)
    end
  end

  it "opens with new" do
    filenames = [] of String

    dir = Dir.new(__DIR__)
    dir.each do |filename|
      filenames << filename
    end
    dir.close

    filenames.includes?("dir_spec.cr").should be_true
  end

  it "opens with open" do
    filenames = [] of String

    Dir.open(__DIR__) do |dir|
      dir.each do |filename|
        filenames << filename
      end
    end

    filenames.includes?("dir_spec.cr").should be_true
  end

  it "lists entries" do
    filenames = Dir.entries(__DIR__)
    filenames.includes?("dir_spec.cr").should be_true
  end

  it "does to_s" do
    Dir.new(__DIR__).to_s.should eq("#<Dir:#{__DIR__}>")
  end
end
