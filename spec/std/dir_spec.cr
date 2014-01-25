#!/usr/bin/env bin/crystal --run
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
  end

  it "tests mkdir with an existing path" do
    begin
      Dir.mkdir(__DIR__, 0700)
      fail "Expected Errno to be raised"
    rescue Errno
    end
  end

  it "tests rmdir with an nonexistent path" do
    begin
      Dir.rmdir("/tmp/crystal_mkdir_test_#{Process.pid}/")
      fail "Expected Errno to be raised"
    rescue Errno
    end
  end

  it "tests rmdir with a path that cannot be removed" do
    begin
      Dir.rmdir(__DIR__)
      fail "Expected Errno to be raised"
    rescue Errno
    end
  end
end
