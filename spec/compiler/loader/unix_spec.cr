{% skip_file if !flag?(:unix) || flag?(:wasm32) %}

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

    it "prepends directory paths before default search paths" do
      loader = Crystal::Loader.parse(%w(-Lfoo -Lbar), search_paths: %w(baz quux))
      loader.search_paths.should eq %w(foo bar baz quux)
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
      exc = expect_raises(Crystal::Loader::LoadError, /no such file|not found|cannot open/i) do
        Crystal::Loader.parse(["foobar.o"], search_paths: [] of String)
      end
      exc.message.should contain File.join(Dir.current, "foobar.o")
      exc = expect_raises(Crystal::Loader::LoadError, /no such file|not found|cannot open/i) do
        Crystal::Loader.parse(["-l", "foo/bar.o"], search_paths: [] of String)
      end
      {% if flag?(:openbsd) %}
        exc.message.should contain "foo/bar.o"
      {% else %}
        exc.message.should contain File.join(Dir.current, "foo", "bar.o")
      {% end %}
    end
  end

  describe ".default_search_paths" do
    it "LD_LIBRARY_PATH" do
      with_env "LD_LIBRARY_PATH": "ld1::ld2", "DYLD_LIBRARY_PATH": nil do
        search_paths = Crystal::Loader.default_search_paths
        {% if flag?(:darwin) %}
          search_paths[-2..].should eq ["/usr/lib", "/usr/local/lib"]
        {% else %}
          search_paths[0, 2].should eq ["ld1", "ld2"]
          {% if flag?(:android) %}
            search_paths[-2..].should eq ["/vendor/lib", "/system/lib"]
          {% else %}
            search_paths[-2..].should eq ["/lib", "/usr/lib"]
          {% end %}
        {% end %}
      end
    end

    it "DYLD_LIBRARY_PATH" do
      with_env "DYLD_LIBRARY_PATH": "ld1::ld2", "LD_LIBRARY_PATH": nil do
        search_paths = Crystal::Loader.default_search_paths
        {% if flag?(:darwin) %}
          search_paths[0, 2].should eq ["ld1", "ld2"]
          search_paths[-2..].should eq ["/usr/lib", "/usr/local/lib"]
        {% elsif flag?(:android) %}
          search_paths[-2..].should eq ["/vendor/lib", "/system/lib"]
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

    describe "#load_file?" do
      it "finds function symbol" do
        loader = Crystal::Loader.new([] of String)
        loader.load_file?(File.join(SPEC_CRYSTAL_LOADER_LIB_PATH, Crystal::Loader.library_filename("foo"))).should be_true
        loader.find_symbol?("foo").should_not be_nil
      ensure
        loader.close_all if loader
      end
    end

    describe "#load_library?" do
      it "library name" do
        loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String)
        loader.load_library?("foo").should be_true
        loader.find_symbol?("foo").should_not be_nil
      ensure
        loader.close_all if loader
      end

      it "full path" do
        loader = Crystal::Loader.new([] of String)
        loader.load_library?(File.join(SPEC_CRYSTAL_LOADER_LIB_PATH, Crystal::Loader.library_filename("foo"))).should be_true
        loader.find_symbol?("foo").should_not be_nil
      ensure
        loader.close_all if loader
      end

      {% unless flag?(:darwin) %}
        # FIXME: bar.c doesn't compile on darwin
        it "does not implicitly find dependencies" do
          build_c_dynlib(compiler_datapath("loader", "bar.c"))
          loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String)
          loader.load_library?("bar").should be_true
          loader.find_symbol?("bar").should_not be_nil
          loader.find_symbol?("foo").should be_nil
        ensure
          loader.close_all if loader
        end
      {% end %}

      it "lookup in order" do
        build_c_dynlib(compiler_datapath("loader", "foo2.c"))

        help_loader1 = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String)
        help_loader1.load_library?("foo").should be_true
        foo_address = help_loader1.find_symbol?("foo").should_not be_nil

        help_loader2 = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String)
        help_loader2.load_library?("foo2").should be_true
        foo2_address = help_loader2.find_symbol?("foo").should_not be_nil

        foo_address.should_not eq foo2_address

        loader1 = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String)
        loader1.load_library("foo")
        loader1.load_library("foo2")

        loader1.find_symbol?("foo").should eq foo_address

        loader2 = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH] of String)
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
