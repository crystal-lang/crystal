require "spec"

describe "Dir" do
  it "tests exists? on existing directory" do
    expect(Dir.exists?(File.join([__DIR__, "../"]))).to be_true
  end

  it "tests exists? on existing file" do
    expect(Dir.exists?(__FILE__)).to be_false
  end

  it "tests exists? on nonexistent directory" do
    expect(Dir.exists?(File.join([__DIR__, "/foo/bar/"]))).to be_false
  end

  it "tests mkdir and rmdir with a new path" do
    path = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    expect(Dir.mkdir(path, 0700)).to eq(0)
    expect(Dir.exists?(path)).to be_true
    expect(Dir.rmdir(path)).to eq(0)
    expect(Dir.exists?(path)).to be_false
  end

  it "tests mkdir with an existing path" do
    expect_raises Errno do
      Dir.mkdir(__DIR__, 0700)
    end
  end

  it "tests mkdir_p with a new path" do
    path = "/tmp/crystal_mkdir_ptest_#{Process.pid}/"
    expect(Dir.mkdir_p(path)).to eq(0)
    expect(Dir.exists?(path)).to be_true
    path = File.join({path, "a", "b", "c"})
    expect(Dir.mkdir_p(path)).to eq(0)
    expect(Dir.exists?(path)).to be_true
  end

  it "tests mkdir_p with an existing path" do
    expect(Dir.mkdir_p(__DIR__)).to eq(0)
    expect_raises Errno do
      Dir.mkdir_p(__FILE__)
    end
  end

  it "tests rmdir with an nonexistent path" do
    expect_raises Errno do
      Dir.rmdir("/tmp/crystal_mkdir_test_#{Process.pid}/")
    end
  end

  it "tests rmdir with a path that cannot be removed" do
    expect_raises Errno do
      Dir.rmdir(__DIR__)
    end
  end

  it "tests glob with a single pattern" do
    result = Dir["#{__DIR__}/*.cr"]
    Dir.foreach(__DIR__) do |file|
      next unless file.ends_with?(".cr")

      expect(result.includes?(File.join(__DIR__, file))).to be_true
    end
  end

  it "tests glob with multiple patterns" do
    result = Dir["#{__DIR__}/*.cr", "#{__DIR__}/{io,html}/*.cr"]

    {__DIR__, "#{__DIR__}/io", "#{__DIR__}/html"}.each do |dir|
      Dir.foreach(dir) do |file|
        next unless file.ends_with?(".cr")
        expect(result.includes?(File.join(dir, file))).to be_true
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

      expect(result.includes?(File.join(__DIR__, file))).to be_true
    end
  end

  describe "chdir" do
    it "should work" do
      cwd = Dir.working_directory
      Dir.chdir("..")
      expect(Dir.working_directory).to_not eq(cwd)
      Dir.cd(cwd)
      expect(Dir.working_directory).to eq(cwd)
    end

    it "raises" do
      expect_raises do
        Dir.chdir("/nope")
      end
    end

    it "accepts a block" do
      cwd = Dir.working_directory

      Dir.chdir("..") do
        expect(Dir.working_directory).to_not eq(cwd)
      end

      expect(Dir.working_directory).to eq(cwd)
    end
  end

  it "opens with new" do
    filenames = [] of String

    dir = Dir.new(__DIR__)
    dir.each do |filename|
      filenames << filename
    end
    dir.close

    expect(filenames.includes?("dir_spec.cr")).to be_true
  end

  it "opens with open" do
    filenames = [] of String

    Dir.open(__DIR__) do |dir|
      dir.each do |filename|
        filenames << filename
      end
    end

    expect(filenames.includes?("dir_spec.cr")).to be_true
  end

  it "lists entries" do
    filenames = Dir.entries(__DIR__)
    expect(filenames.includes?("dir_spec.cr")).to be_true
  end

  it "does to_s" do
    expect(Dir.new(__DIR__).to_s).to eq("#<Dir:#{__DIR__}>")
  end
end
