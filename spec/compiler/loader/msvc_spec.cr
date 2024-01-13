{% skip_file if !flag?(:msvc) %}

require "./spec_helper"
require "../spec_helper"
require "../../support/env"
require "compiler/crystal/loader"

describe Crystal::Loader do
  describe ".parse" do
    it "parses directory paths" do
      loader = Crystal::Loader.parse([%q(/LIBPATH:C:\foo\bar), "/LIBPATH:baz"], search_paths: [] of String)
      loader.search_paths.should eq [%q(C:\foo\bar), "baz"]
    end

    it "prepends directory paths before default search paths" do
      loader = Crystal::Loader.parse(%w(/LIBPATH:foo /LIBPATH:bar), search_paths: %w(baz quux))
      loader.search_paths.should eq %w(foo bar baz quux)
    end

    it "parses file paths" do
      expect_raises(Crystal::Loader::LoadError, "cannot find foobar.lib") do
        Crystal::Loader.parse(["foobar.lib"], search_paths: [] of String)
      end
    end
  end

  describe ".default_search_paths" do
    it "LIB" do
      with_env "LIB": "foo;;bar" do
        search_paths = Crystal::Loader.default_search_paths
        search_paths.should eq ["foo", "bar"]
      end
    end
  end

  describe "dll" do
    before_all do
      FileUtils.mkdir_p(SPEC_CRYSTAL_LOADER_LIB_PATH)
      build_c_dynlib(compiler_datapath("loader", "foo.c"))
    end

    after_all do
      FileUtils.rm_rf(SPEC_CRYSTAL_LOADER_LIB_PATH)
    end

    describe "#load_file?" do
      it "finds function symbol" do
        loader = Crystal::Loader.new([] of String, dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
        loader.load_file?(File.join(SPEC_CRYSTAL_LOADER_LIB_PATH, Crystal::Loader.library_filename("foo"))).should be_true
        loader.find_symbol?("foo").should_not be_nil
      ensure
        loader.close_all if loader
      end
    end

    describe "#load_library?" do
      it "library name" do
        loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
        loader.load_library?("foo").should be_true
        loader.find_symbol?("foo").should_not be_nil
      ensure
        loader.close_all if loader
      end

      it "full path" do
        loader = Crystal::Loader.new([] of String, dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
        loader.load_library?(File.join(SPEC_CRYSTAL_LOADER_LIB_PATH, Crystal::Loader.library_filename("foo"))).should be_true
        loader.find_symbol?("foo").should_not be_nil
      ensure
        loader.close_all if loader
      end

      it "does not implicitly find dependencies" do
        build_c_dynlib(compiler_datapath("loader", "bar.c"))
        loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
        loader.load_library?("bar").should be_true
        loader.find_symbol?("bar").should_not be_nil
        loader.find_symbol?("foo").should be_nil
      ensure
        loader.close_all if loader
      end

      it "lookup in order" do
        build_c_dynlib(compiler_datapath("loader", "foo2.c"))

        help_loader1 = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
        help_loader1.load_library?("foo").should be_true
        foo_address = help_loader1.find_symbol?("foo").should_not be_nil

        help_loader2 = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
        help_loader2.load_library?("foo2").should be_true
        foo2_address = help_loader2.find_symbol?("foo").should_not be_nil

        foo_address.should_not eq foo2_address

        loader1 = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
        loader1.load_library("foo")
        loader1.load_library("foo2")

        loader1.find_symbol?("foo").should eq foo_address

        loader2 = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
        loader2.load_library("foo2")
        loader2.load_library("foo")

        loader2.find_symbol?("foo").should eq foo2_address
      ensure
        help_loader1.try &.close_all
        help_loader2.try &.close_all

        loader1.try &.close_all
        loader2.try &.close_all
      end
    end

    it "does not find global symbols" do
      loader = Crystal::Loader.new([] of String, dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
      loader.find_symbol?("__crystal_main").should be_nil
    end

    it "validate that lib handles are properly closed" do
      loader = Crystal::Loader.new([] of String, dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
      expect_raises(Crystal::Loader::LoadError, "undefined reference to `foo'") do
        loader.find_symbol("foo")
      end
    end
  end

  describe "dll_search_paths" do
    it "supports an arbitrary path different from lib search path" do
      with_tempfile("loader-dll_search_paths") do |path|
        FileUtils.mkdir_p(SPEC_CRYSTAL_LOADER_LIB_PATH)
        FileUtils.mkdir_p(path)

        build_c_dynlib(compiler_datapath("loader", "foo.c"))
        File.rename(File.join(SPEC_CRYSTAL_LOADER_LIB_PATH, "foo.dll"), File.join(path, "foo.dll"))

        loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String, dll_search_paths: [path])
        loader.load_library?("foo").should be_true
      ensure
        loader.try &.close_all

        FileUtils.rm_rf(path)
        FileUtils.rm_rf(SPEC_CRYSTAL_LOADER_LIB_PATH)
      end
    end

    it "doesn't load DLLs outside dll_search_path or Windows' default search paths" do
      with_tempfile("loader-dll_search_paths") do |path|
        FileUtils.mkdir_p(SPEC_CRYSTAL_LOADER_LIB_PATH)
        FileUtils.mkdir_p(path)

        build_c_dynlib(compiler_datapath("loader", "foo.c"))
        File.rename(File.join(SPEC_CRYSTAL_LOADER_LIB_PATH, "foo.dll"), File.join(path, "foo.dll"))

        loader1 = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String, dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
        loader1.load_library?("foo").should be_false
        loader2 = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String)
        loader2.load_library?("foo").should be_false
      ensure
        loader2.try &.close_all
        loader1.try &.close_all

        FileUtils.rm_rf(path)
        FileUtils.rm_rf(SPEC_CRYSTAL_LOADER_LIB_PATH)
      end
    end
  end

  describe "lib suffix" do
    before_all do
      FileUtils.mkdir_p(SPEC_CRYSTAL_LOADER_LIB_PATH)
    end

    after_all do
      FileUtils.rm_rf(SPEC_CRYSTAL_LOADER_LIB_PATH)
    end

    it "respects -dynamic" do
      build_c_dynlib(compiler_datapath("loader", "foo.c"), lib_name: "foo-dynamic")
      loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
      loader.load_library?("foo").should be_true
    ensure
      loader.close_all if loader
    end

    it "ignores -static" do
      build_c_dynlib(compiler_datapath("loader", "foo.c"), lib_name: "bar-static")
      loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: [SPEC_CRYSTAL_LOADER_LIB_PATH])
      loader.load_library?("bar").should be_false
    ensure
      loader.close_all if loader
    end
  end
end
