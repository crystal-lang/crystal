require "spec"

private def assert_dir_glob(*patterns, expected_result)
  result = Dir[*patterns]
  result.sort.should eq(expected_result.sort)
end

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
    Dir.mkdir(path, 0o700).should eq(0)
    Dir.exists?(path).should be_true
    Dir.rmdir(path).should eq(0)
    Dir.exists?(path).should be_false
  end

  it "tests mkdir with an existing path" do
    expect_raises Errno do
      Dir.mkdir(__DIR__, 0o700)
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

  describe "glob" do
    it "tests glob with a single pattern" do
      assert_dir_glob "#{__DIR__}/data/dir/*.txt",
        [
          "#{__DIR__}/data/dir/f1.txt",
          "#{__DIR__}/data/dir/f2.txt",
          "#{__DIR__}/data/dir/g2.txt",
        ]
    end

    it "tests glob with multiple patterns" do
      assert_dir_glob "#{__DIR__}/data/dir/*.txt", "#{__DIR__}/data/dir/subdir/*.txt",
        [
          "#{__DIR__}/data/dir/f1.txt",
          "#{__DIR__}/data/dir/f2.txt",
          "#{__DIR__}/data/dir/g2.txt",
          "#{__DIR__}/data/dir/subdir/f1.txt",
        ]
    end

    it "tests glob with a single pattern with block" do
      result = [] of String
      Dir.glob("#{__DIR__}/data/dir/*.txt") do |filename|
        result << filename
      end
      result.sort.should eq([
        "#{__DIR__}/data/dir/f1.txt",
        "#{__DIR__}/data/dir/f2.txt",
        "#{__DIR__}/data/dir/g2.txt",
      ].sort)
    end

    it "tests a recursive glob" do
      assert_dir_glob "#{__DIR__}/data/dir/**/*.txt",
        [
          "#{__DIR__}/data/dir/f1.txt",
          "#{__DIR__}/data/dir/f2.txt",
          "#{__DIR__}/data/dir/g2.txt",
          "#{__DIR__}/data/dir/subdir/f1.txt",
          "#{__DIR__}/data/dir/subdir/subdir2/f2.txt",
        ]
    end

    it "tests a recursive glob with '?'" do
      assert_dir_glob "#{__DIR__}/data/dir/f?.tx?",
        [
          "#{__DIR__}/data/dir/f1.txt",
          "#{__DIR__}/data/dir/f2.txt",
          "#{__DIR__}/data/dir/f3.txx",
        ]
    end

    it "tests a recursive glob with alternation" do
      assert_dir_glob "#{__DIR__}/data/{dir,dir/subdir}/*.txt",
        [
          "#{__DIR__}/data/dir/f1.txt",
          "#{__DIR__}/data/dir/f2.txt",
          "#{__DIR__}/data/dir/g2.txt",
          "#{__DIR__}/data/dir/subdir/f1.txt",
        ]
    end

    it "tests a glob with recursion inside alternation" do
      assert_dir_glob "#{__DIR__}/data/dir/{**/*.txt,**/*.txx}",
        [
          "#{__DIR__}/data/dir/f1.txt",
          "#{__DIR__}/data/dir/f2.txt",
          "#{__DIR__}/data/dir/f3.txx",
          "#{__DIR__}/data/dir/g2.txt",
          "#{__DIR__}/data/dir/subdir/f1.txt",
          "#{__DIR__}/data/dir/subdir/subdir2/f2.txt",
        ]
    end

    it "tests a recursive glob with nested alternations" do
      assert_dir_glob "#{__DIR__}/data/dir/{?1.*,{f,g}2.txt}",
        [
          "#{__DIR__}/data/dir/f1.txt",
          "#{__DIR__}/data/dir/f2.txt",
          "#{__DIR__}/data/dir/g2.txt",
        ]
    end

    it "tests with *" do
      assert_dir_glob "#{__DIR__}/data/dir/*",
        [
          "#{__DIR__}/data/dir/f1.txt",
          "#{__DIR__}/data/dir/f2.txt",
          "#{__DIR__}/data/dir/f3.txx",
          "#{__DIR__}/data/dir/g2.txt",
          "#{__DIR__}/data/dir/subdir",
          "#{__DIR__}/data/dir/subdir2",
        ]
    end

    it "tests with ** (same as *)" do
      assert_dir_glob "#{__DIR__}/data/dir/**",
        [
          "#{__DIR__}/data/dir/f1.txt",
          "#{__DIR__}/data/dir/f2.txt",
          "#{__DIR__}/data/dir/f3.txx",
          "#{__DIR__}/data/dir/g2.txt",
          "#{__DIR__}/data/dir/subdir",
          "#{__DIR__}/data/dir/subdir2",
        ]
    end

    it "tests with */" do
      assert_dir_glob "#{__DIR__}/data/dir/*/",
        [
          "#{__DIR__}/data/dir/subdir/",
          "#{__DIR__}/data/dir/subdir2/",
        ]
    end

    it "tests glob with a single pattern with extra slashes" do
      assert_dir_glob "#{__DIR__}////data////dir////*.txt",
        [
          "#{__DIR__}/data/dir/f1.txt",
          "#{__DIR__}/data/dir/f2.txt",
          "#{__DIR__}/data/dir/g2.txt",
        ]
    end
  end

  describe "cd" do
    it "should work" do
      cwd = Dir.working_directory
      Dir.cd("..")
      Dir.working_directory.should_not eq(cwd)
      Dir.cd(cwd)
      Dir.working_directory.should eq(cwd)
    end

    it "raises" do
      expect_raises do
        Dir.cd("/nope")
      end
    end

    it "accepts a block" do
      cwd = Dir.working_directory

      Dir.cd("..") do
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

  it "gets dir iterator" do
    filenames = [] of String

    iter = Dir.new(__DIR__).each
    iter.each do |filename|
      filenames << filename
    end

    filenames.includes?("dir_spec.cr").should be_true
  end

  it "double close doesn't error" do
    dir = Dir.open(__DIR__) do |dir|
      dir.close
      dir.close
    end
  end
end
