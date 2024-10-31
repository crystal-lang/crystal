{% skip_file if flag?(:without_ffi) || flag?(:wasm32) %}
{% skip_file unless flag?(:unix) || flag?(:win32) %}

require "../spec_helper"
require "compiler/crystal/ffi"
require "compiler/crystal/loader"
require "../loader/spec_helper"

# all the integral return types must be at least as large as the register size
# to avoid integer promotion by FFI!

@[Extern]
private record TestStruct,
  b : Int8,
  s : Int16,
  i : Int32,
  j : Int64,
  f : Float32,
  d : Float64,
  p : Pointer(Void)

private def dll_search_paths
  {% if flag?(:msvc) %}
    [SPEC_CRYSTAL_LOADER_LIB_PATH]
  {% else %}
    nil
  {% end %}
end

{% if flag?(:unix) || (flag?(:win32) && flag?(:gnu)) %}
  class Crystal::Loader
    def self.new(search_paths : Array(String), *, dll_search_paths : Nil)
      new(search_paths)
    end
  end
{% end %}

describe Crystal::FFI::CallInterface do
  before_all do
    FileUtils.mkdir_p(SPEC_CRYSTAL_LOADER_LIB_PATH)
    build_c_dynlib(compiler_datapath("ffi", "sum.c"))

    {% if flag?(:win32) && flag?(:gnu) %}
      ENV["PATH"] = "#{SPEC_CRYSTAL_LOADER_LIB_PATH}#{Process::PATH_DELIMITER}#{ENV["PATH"]}"
    {% end %}
  end

  after_all do
    {% if flag?(:win32) && flag?(:gnu) %}
      ENV["PATH"] = ENV["PATH"].delete_at(0, ENV["PATH"].index!(Process::PATH_DELIMITER) + 1)
    {% end %}

    FileUtils.rm_rf(SPEC_CRYSTAL_LOADER_LIB_PATH)
  end

  describe ".new" do
    it "simple call" do
      call_interface = Crystal::FFI::CallInterface.new Crystal::FFI::Type.sint64, [] of Crystal::FFI::Type

      loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: dll_search_paths)
      loader.load_library "sum"
      function_pointer = loader.find_symbol("answer")
      return_value = 0_i64
      call_interface.call(function_pointer, Pointer(Pointer(Void)).null, pointerof(return_value).as(Void*))
      return_value.should eq 42_i64
    ensure
      loader.try &.close_all
    end

    it "with args" do
      call_interface = Crystal::FFI::CallInterface.new Crystal::FFI::Type.sint64, [
        Crystal::FFI::Type.sint32, Crystal::FFI::Type.sint32, Crystal::FFI::Type.sint32,
      ] of Crystal::FFI::Type

      loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: dll_search_paths)
      loader.load_library "sum"
      function_pointer = loader.find_symbol("sum")

      return_value = 0_i64
      args = Int32[1, 3, 5]
      arg_pointers = StaticArray(Pointer(Void), 3).new { |i| (args.to_unsafe + i).as(Void*) }
      call_interface.call(function_pointer, arg_pointers.to_unsafe, pointerof(return_value).as(Void*))
      return_value.should eq 9_i64
    ensure
      loader.try &.close_all
    end

    it "all primitive arg types" do
      call_interface = Crystal::FFI::CallInterface.new Crystal::FFI::Type.void, [
        Crystal::FFI::Type.uint8, Crystal::FFI::Type.sint8,
        Crystal::FFI::Type.uint16, Crystal::FFI::Type.sint16,
        Crystal::FFI::Type.uint32, Crystal::FFI::Type.sint32,
        Crystal::FFI::Type.uint64, Crystal::FFI::Type.sint64,
        Crystal::FFI::Type.float, Crystal::FFI::Type.double,
        Crystal::FFI::Type.pointer,
      ] of Crystal::FFI::Type

      loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: dll_search_paths)
      loader.load_library "sum"
      function_pointer = loader.find_symbol("sum_primitive_types")

      pointer_value = 11_i64
      arg_pointers = StaticArray[
        Pointer(UInt8).malloc(1, 1).as(Void*),
        Pointer(Int8).malloc(1, 2).as(Void*),
        Pointer(UInt16).malloc(1, 3).as(Void*),
        Pointer(Int16).malloc(1, 4).as(Void*),
        Pointer(UInt32).malloc(1, 5).as(Void*),
        Pointer(Int32).malloc(1, 6).as(Void*),
        Pointer(UInt64).malloc(1, 7).as(Void*),
        Pointer(Int64).malloc(1, 8).as(Void*),
        Pointer(Float32).malloc(1, 9.0).as(Void*),
        Pointer(Float64).malloc(1, 10.0).as(Void*),
        Pointer(Int64*).malloc(1, pointerof(pointer_value)).as(Void*),
        Pointer(Void).null,
      ]

      call_interface.call(function_pointer, arg_pointers.to_unsafe, Pointer(Void).null)
      pointer_value.should eq 66
    ensure
      loader.try &.close_all
    end

    it "make struct" do
      struct_fields = [
        Crystal::FFI::Type.sint8,
        Crystal::FFI::Type.sint16,
        Crystal::FFI::Type.sint32,
        Crystal::FFI::Type.sint64,
        Crystal::FFI::Type.float,
        Crystal::FFI::Type.double,
        Crystal::FFI::Type.pointer,
      ]
      call_interface = Crystal::FFI::CallInterface.new Crystal::FFI::Type.struct(struct_fields), struct_fields

      loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: dll_search_paths)
      loader.load_library "sum"
      function_pointer = loader.find_symbol("make_struct")

      pointer_value = "foobar"
      arg_pointers = StaticArray[
        Pointer(Int8).malloc(1, 2).as(Void*),
        Pointer(Int16).malloc(1, 4).as(Void*),
        Pointer(Int32).malloc(1, 6).as(Void*),
        Pointer(Int64).malloc(1, 8).as(Void*),
        Pointer(Float32).malloc(1, 9.0).as(Void*),
        Pointer(Float64).malloc(1, 10.0).as(Void*),
        Pointer(UInt8*).malloc(1, pointer_value.to_unsafe).as(Void*),
        Pointer(Void).null,
      ]

      return_value = uninitialized TestStruct
      call_interface.call(function_pointer, arg_pointers.to_unsafe, pointerof(return_value).as(Void*))
      return_value.should eq TestStruct.new b: 2, s: 4, i: 6, j: 8, f: 9.0, d: 10.0, p: pointer_value.to_unsafe.as(Void*)
    ensure
      loader.try &.close_all
    end

    it "sum struct" do
      call_interface = Crystal::FFI::CallInterface.new Crystal::FFI::Type.sint64, [
        Crystal::FFI::Type.struct([
          Crystal::FFI::Type.sint8,
          Crystal::FFI::Type.sint16,
          Crystal::FFI::Type.sint32,
          Crystal::FFI::Type.sint64,
          Crystal::FFI::Type.float,
          Crystal::FFI::Type.double,
          Crystal::FFI::Type.pointer,
        ]),
      ] of Crystal::FFI::Type

      loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: dll_search_paths)
      loader.load_library "sum"
      function_pointer = loader.find_symbol("sum_struct")

      pointer_value = 11_i64
      arg_pointers = StaticArray[
        Pointer(TestStruct).malloc(1, TestStruct.new(
          b: 2,
          s: 4,
          i: 6,
          j: 8,
          f: 9.0,
          d: 10.0,
          p: pointerof(pointer_value).as(Void*)
        )).as(Void*),
        Pointer(Void).null,
      ]

      return_value = 0_i64
      call_interface.call(function_pointer, arg_pointers.to_unsafe, pointerof(return_value).as(Void*))
      return_value.should eq 50_i64
      pointer_value.should eq 50_i64
    ensure
      loader.try &.close_all
    end

    # passing C array by value is not supported everywhere
    {% unless flag?(:win32) %}
      it "array" do
        call_interface = Crystal::FFI::CallInterface.new Crystal::FFI::Type.sint64, [
          Crystal::FFI::Type.struct([
            Crystal::FFI::Type.sint32,
            Crystal::FFI::Type.sint32,
            Crystal::FFI::Type.sint32,
            Crystal::FFI::Type.sint32,
          ]),
        ] of Crystal::FFI::Type

        loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: dll_search_paths)
        loader.load_library "sum"
        function_pointer = loader.find_symbol("sum_array")

        return_value = 0_i64

        ary = [1, 2, 3, 4]

        arg_pointers = StaticArray[
          Pointer.malloc(1, ary.to_unsafe).as(Void*),
          Pointer(Void).null,
        ]

        call_interface.call(function_pointer, arg_pointers.to_unsafe, pointerof(return_value).as(Void*))
        return_value.should eq 10_i64
      ensure
        loader.try &.close_all
      end
    {% end %}
  end

  describe ".variadic" do
    it "basic" do
      call_interface = Crystal::FFI::CallInterface.variadic Crystal::FFI::Type.sint64, [Crystal::FFI::Type.sint32, Crystal::FFI::Type.sint32, Crystal::FFI::Type.sint32, Crystal::FFI::Type.sint32] of Crystal::FFI::Type, 1

      loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: dll_search_paths)
      loader.load_library "sum"
      function_pointer = loader.find_symbol("sum_variadic")

      return_value = 0_i64
      args = Int32[3, 1, 3, 5]
      arg_pointers = StaticArray(Pointer(Void), 4).new { |i| (args.to_unsafe + i).as(Void*) }
      call_interface.call(function_pointer, arg_pointers.to_unsafe, pointerof(return_value).as(Void*))
      return_value.should eq 9_i64
    ensure
      loader.try &.close_all
    end

    it "zero varargs" do
      call_interface = Crystal::FFI::CallInterface.variadic Crystal::FFI::Type.sint64, [Crystal::FFI::Type.sint32] of Crystal::FFI::Type, 1

      loader = Crystal::Loader.new([SPEC_CRYSTAL_LOADER_LIB_PATH], dll_search_paths: dll_search_paths)
      loader.load_library "sum"
      function_pointer = loader.find_symbol("sum_variadic")

      return_value = 1_i64
      count = 0_i32
      arg_pointer = pointerof(count).as(Void*)
      call_interface.call(function_pointer, pointerof(arg_pointer), pointerof(return_value).as(Void*))
      return_value.should eq 0_i64
    ensure
      loader.try &.close_all
    end

    it "validates args size" do
      expect_raises Exception, "invalid value for fixed_args" do
        Crystal::FFI::CallInterface.variadic Crystal::FFI::Type.sint64, [] of Crystal::FFI::Type, 1
      end
      expect_raises Exception, "invalid value for fixed_args" do
        Crystal::FFI::CallInterface.variadic Crystal::FFI::Type.sint64, [] of Crystal::FFI::Type, -1
      end
    end
  end
end
