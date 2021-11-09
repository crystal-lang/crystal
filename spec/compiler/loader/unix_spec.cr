{% skip_file unless flag?(:unix) %}

require "./spec_helper"
require "../spec_helper"
require "../../support/env"
require "compiler/crystal/loader"

describe Crystal::Loader do
  describe ".parse" do
    it "parses directory paths" do
      loader = Crystal::Loader.parse(["-L", "/foo/bar/baz", "--library-path", "qux"], search_paths: [] of String)
      loader.search_paths.should eq ["/foo/bar/baz", "qux"]
    end

    it "parses static" do
      expect_raises(Crystal::Loader::LoadError, "static libraries are not supported by Crystal's runtime loader") do
        Crystal::Loader.parse(["-static"], search_paths: [] of String)
      end
    end

    it "parses library names" do
      expect_raises(Crystal::Loader::LoadError, "cannot find -lfoobar") do
        Crystal::Loader.parse(["-l", "foobar"], search_paths: [] of String)
      end
      expect_raises(Crystal::Loader::LoadError, "cannot find -lfoobar") do
        Crystal::Loader.parse(["--library", "foobar"], search_paths: [] of String)
      end
    end

    it "parses file paths" do
      expect_raises(Crystal::Loader::LoadError, /#{Dir.current}\/foobar\.o.+(No such file or directory|image not found)/) do
        Crystal::Loader.parse(["foobar.o"], search_paths: [] of String)
      end
      expect_raises(Crystal::Loader::LoadError, /#{Dir.current}\/foo\/bar\.o.+(No such file or directory|image not found)/) do
        Crystal::Loader.parse(["-l", "foo/bar.o"], search_paths: [] of String)
      end
    end
  end

  describe ".default_search_paths" do
    it "LD_LIBRARY_PATH" do
      with_env "LD_LIBRARY_PATH": "ld1::ld2", "DYLD_LIBRARY_PATH": nil do
        search_paths = Crystal::Loader.default_search_paths
        {% if flag?(:darwin) %}
          search_paths.should eq ["/usr/lib", "/usr/local/lib"]
        {% else %}
          search_paths[0, 2].should eq ["ld1", "ld2"]
          search_paths[-2..].should eq ["/lib", "/usr/lib"]
        {% end %}
      end
    end

    it "DYLD_LIBRARY_PATH" do
      with_env "DYLD_LIBRARY_PATH": "ld1::ld2", "LD_LIBRARY_PATH": nil do
        search_paths = Crystal::Loader.default_search_paths
        {% if flag?(:darwin) %}
          search_paths[0, 2].should eq ["ld1", "ld2"]
          search_paths[-2..].should eq ["/usr/lib", "/usr/local/lib"]
        {% else %}
          search_paths[-2..].should eq ["/lib", "/usr/lib"]
        {% end %}
      end
    end
  end

  describe ".read_ld_conf" do
    it "basic" do
      ary = [] of String
      Crystal::Loader.read_ld_conf(ary, compiler_datapath("loader/ld.so/basic.conf"))
      ary.should eq ["foo/bar", "baz/qux"]
    end

    it "with include" do
      ary = [] of String
      Crystal::Loader.read_ld_conf(ary, compiler_datapath("loader/ld.so/include.conf"))
      ary[0].should eq "include/before"
      ary[-1].should eq "include/after"
      # the order between basic.conf and basic2.conf is system-dependent
      ary[1..-2].sort.should eq ["baz/qux", "foo/bar", "foobar"]
    end
  end

  describe "dynlib" do
    before_all do
      FileUtils.mkdir_p(SPEC_CRYSTAL_LOADER_LIB_PATH)
      build_c_dynlib(compiler_datapath("loader", "foo.c"))
    end

    after_all do
      FileUtils.rm_rf(SPEC_CRYSTAL_LOADER_LIB_PATH)
    end

    describe "#load_file" do
      it "finds function symbol" do
        loader = Crystal::Loader.new([] of String)
        lib_handle = loader.load_file(File.join(SPEC_CRYSTAL_LOADER_LIB_PATH, "libfoo#{Crystal::Loader::SHARED_LIBRARY_EXTENSION}"))
        lib_handle.should_not be_nil
        loader.find_symbol?("foo").should_not be_nil
      ensure
        loader.close_all if loader
      end
    end

    describe "#load_library" do
      it "library name" do
        loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String)
        lib_handle = loader.load_library("foo")
        lib_handle.should_not be_nil
        loader.find_symbol?("foo").should_not be_nil
      ensure
        loader.close_all if loader
      end

      it "full path" do
        loader = Crystal::Loader.new([] of String)
        lib_handle = loader.load_library(File.join(SPEC_CRYSTAL_LOADER_LIB_PATH, "libfoo#{Crystal::Loader::SHARED_LIBRARY_EXTENSION}"))
        lib_handle.should_not be_nil
        loader.find_symbol?("foo").should_not be_nil
      ensure
        loader.close_all if loader
      end

      {% unless flag?(:darwin) %}
        # FIXME: bar.c doesn't compile on darwin
        it "does not implicitly find dependencies" do
          build_c_dynlib(compiler_datapath("loader", "bar.c"))
          loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String)
          lib_handle = loader.load_library("bar")
          lib_handle.should_not be_nil
          loader.find_symbol?("bar").should_not be_nil
          loader.find_symbol?("foo").should be_nil
        ensure
          loader.close_all if loader
        end
      {% end %}
    end

    it "does not find global symbols" do
      loader = Crystal::Loader.new([] of String)
      loader.find_symbol?("__crystal_main").should be_nil
    end

    it "validate that lib handles are properly closed" do
      loader = Crystal::Loader.new([] of String)
      expect_raises(Crystal::Loader::LoadError, "undefined reference to `foo'") do
        loader.find_symbol("foo")
      end
    end
  end
end
