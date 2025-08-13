{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"
require "../loader/spec_helper"

private def ldflags
  {% if flag?(:msvc) %}
    "/LIBPATH:#{SPEC_CRYSTAL_LOADER_LIB_PATH} sum.lib"
  {% else %}
    "-L#{SPEC_CRYSTAL_LOADER_LIB_PATH} -lsum"
  {% end %}
end

private def ldflags_with_backtick
  {% if flag?(:msvc) %}
    "/LIBPATH:#{SPEC_CRYSTAL_LOADER_LIB_PATH} `powershell.exe -C Write-Host -NoNewline sum.lib`"
  {% else %}
    "-L#{SPEC_CRYSTAL_LOADER_LIB_PATH} -l`echo sum`"
  {% end %}
end

describe Crystal::Repl::Interpreter do
  before_all do
    FileUtils.mkdir_p(SPEC_CRYSTAL_LOADER_LIB_PATH)
    build_c_dynlib(compiler_datapath("interpreter", "sum.c"))

    {% if flag?(:win32) %}
      ENV["PATH"] = "#{SPEC_CRYSTAL_LOADER_LIB_PATH}#{Process::PATH_DELIMITER}#{ENV["PATH"]}"
    {% end %}
  end

  after_all do
    {% if flag?(:win32) %}
      ENV["PATH"] = ENV["PATH"].delete_at(0, ENV["PATH"].index!(Process::PATH_DELIMITER) + 1)
    {% end %}

    FileUtils.rm_rf(SPEC_CRYSTAL_LOADER_LIB_PATH)
  end

  context "variadic calls" do
    it "promotes float" do
      interpret(<<-CRYSTAL).should eq 3.5
        @[Link(ldflags: #{ldflags.inspect})]
        lib LibSum
          fun sum_float(count : Int32, ...) : Float32
        end

        LibSum.sum_float(2, 1.2_f32, 2.3_f32)
        CRYSTAL
    end

    it "promotes int" do
      interpret(<<-CRYSTAL).should eq 5
        @[Link(ldflags: #{ldflags.inspect})]
        lib LibSum
          fun sum_int(count : Int32, ...) : Int32
        end

        LibSum.sum_int(2, 1_u8, 4_i16)
        CRYSTAL
    end

    it "promotes enum" do
      interpret(<<-CRYSTAL).should eq 5
        @[Link(ldflags: #{ldflags.inspect})]
        lib LibSum
          fun sum_int(count : Int32, ...) : Int32
        end

        enum E : Int8
          ONE = 1
        end

        enum F : UInt16
          FOUR = 4
        end

        LibSum.sum_int(2, E::ONE, F::FOUR)
        CRYSTAL
    end
  end

  context "command expansion" do
    it "expands ldflags" do
      interpret(<<-CRYSTAL).should eq 4
        @[Link(ldflags: #{ldflags_with_backtick.inspect})]
        lib LibSum
          fun simple_sum_int(a : Int32, b : Int32) : Int32
        end

        LibSum.simple_sum_int(2, 2)
        CRYSTAL
    end
  end
end
