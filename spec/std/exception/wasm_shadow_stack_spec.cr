{% skip_file unless flag?(:wasm32) %}

require "spec"

private def shadow_nested(depth : Int32) : Array(String)
  return caller if depth == 0
  shadow_nested(depth - 1)
end

private def shadow_raise
  raise "shadow stack test"
end

private def shadow_capture
  caller
end

private class ShadowInitialized
  @@trace : Array(String) = shadow_capture

  def self.trace
    @@trace
  end
end

private def shadow_early_return
  return shadow_capture
ensure
  shadow_capture
end

@[Raises]
fun shadow_return_closure(value : Int32) : -> Int32
  -> { value }
end

private class ShadowCallback
  class_property trace = [] of String
end

fun shadow_callback(a : Void*, b : Void*) : Int32
  ShadowCallback.trace = caller
  0
end

lib ShadowHost
  fun qsort(base : Void*, count : LibC::SizeT, size : LibC::SizeT, compare : (Void*, Void* -> Int32)) : Void
end

SHADOW_INITIALIZER_TRACE = shadow_capture
shadow_top_level_trace = caller

if shadow_top_level_trace.empty?
  describe "WASM shadow stack without debug information" do
    it "returns empty caller and exception traces" do
      shadow_capture.should be_empty
      begin
        shadow_raise
      rescue ex
        ex.backtrace.should be_empty
      end
    end
  end
else
  describe "WASM shadow stack" do
    it "captures top-level code and filters runtime frames" do
      shadow_top_level_trace.any?(&.includes?("in '__crystal_main'")).should be_true
      shadow_capture.none?(&.includes?("src/exception/call_stack")).should be_true
    end

    it "captures recursion and keeps snapshots after returning" do
      trace = shadow_nested(4)
      trace.count(&.includes?("in 'shadow_nested'")).should eq(5)
      original = trace.dup
      shadow_nested(8)
      trace.should eq(original)
      caller.none?(&.includes?("in 'shadow_nested'")).should be_true
    end

    it "captures closures and indirect calls" do
      value = 42
      closure = -> { value; shadow_capture }
      trace = closure.call
      trace.any?(&.includes?("in 'shadow_capture'")).should be_true
      trace.any?(&.includes?("in '->'")).should be_true
      trace.any?(&.includes?("wasm_shadow_stack_spec.cr:")).should be_true
    end

    it "captures source initializers" do
      ShadowInitialized.trace.any?(&.includes?("in 'shadow_capture'")).should be_true
      SHADOW_INITIALIZER_TRACE.any?(&.includes?("in 'shadow_capture'")).should be_true
    end

    it "restores frames after early returns with ensure" do
      shadow_early_return.any?(&.includes?("in 'shadow_early_return'")).should be_true
      caller.none?(&.includes?("in 'shadow_early_return'")).should be_true
    end

    it "captures exported Crystal callbacks" do
      values = StaticArray[2, 1]
      ShadowHost.qsort(values.to_unsafe, values.size, sizeof(Int32), ->shadow_callback(Void*, Void*))
      ShadowCallback.trace.any?(&.includes?("in 'shadow_callback'")).should be_true
      caller.none?(&.includes?("in 'shadow_callback'")).should be_true
    end

    it "keeps frames until potentially raising return conversions finish" do
      shadow_return_closure(1)
      fail "expected a closure conversion error"
    rescue ex
      ex.backtrace.any?(&.includes?("in 'shadow_return_closure'")).should be_true
      caller.none?(&.includes?("in 'shadow_return_closure'")).should be_true
    end

    it "restores frames when ensure raises a new exception" do
      begin
        begin
          shadow_raise
        ensure
          shadow_raise
        end
      rescue ex
        ex.backtrace.count(&.includes?("in 'shadow_raise'")).should eq(1)
        caller.none?(&.includes?("in 'shadow_raise'")).should be_true
      end
    end

    it "restores frames across repeated rescue and ensure execution" do
      10.times do
        ensured = false
        begin
          begin
            shadow_raise
          ensure
            ensured = true
            caller.none?(&.includes?("in 'shadow_raise'")).should be_true
          end
        rescue ex
          ensured.should be_true
          trace = ex.backtrace
          trace.any?(&.includes?("in 'shadow_raise'")).should be_true
          begin
            raise ex
          rescue again
            again.backtrace.should eq(trace)
          end
          begin
            shadow_raise
          rescue
            caller.none?(&.includes?("in 'shadow_raise'")).should be_true
          end
        end
        caller.none?(&.includes?("in 'shadow_raise'")).should be_true
      end
    end
  end
end
