require "../spec_helper"

private def print_error_to_s(format, *args)
  io = IO::Memory.new
  Crystal::System.print_error(format, *args) do |bytes|
    io.write_string(bytes)
  end
  io.to_s
end

describe "Crystal::System" do
  describe ".print_error" do
    it "works" do
      print_error_to_s("abcde").should eq("abcde")
    end

    it "supports %d" do
      print_error_to_s("%d,%d,%d,%d,%d", 0, 1234, Int32::MAX, Int32::MIN, UInt64::MAX).should eq("0,1234,2147483647,-2147483648,-1")
    end

    it "supports %u" do
      print_error_to_s("%u,%u,%u,%u,%u", 0, 1234, UInt32::MAX, Int32::MIN, UInt64::MAX).should eq("0,1234,4294967295,2147483648,4294967295")
    end

    it "supports %x" do
      print_error_to_s("%x,%x,%x,%x,%x", 0, 0x1234, UInt32::MAX, Int32::MIN, UInt64::MAX).should eq("0,1234,ffffffff,80000000,ffffffff")
    end

    # TODO: investigate why this prints `(???)`
    pending_interpreted "supports %p" do
      print_error_to_s("%p,%p,%p", Pointer(Void).new(0x0), Pointer(Void).new(0x1234), Pointer(Void).new(UInt64::MAX)).should eq("0x0,0x1234,0xffffffffffffffff")
    end

    it "supports %s" do
      print_error_to_s("%s,%s,%s", "abc\0def", "ghi".to_unsafe, Pointer(UInt8).null).should eq("abc\0def,ghi,(null)")
    end

    # BUG: missing downcast_distinct from Tuple(Int64 | UInt64, Int64 | UInt64, Int64 | UInt64, Int64 | UInt64) to Tuple(Int64, Int64, Int64, Int64)
    pending_interpreted "supports %l width" do
      values = {LibC::Long::MIN, LibC::Long::MAX, LibC::LongLong::MIN, LibC::LongLong::MAX}
      print_error_to_s("%ld,%ld,%lld,%lld", *values).should eq(values.join(','))

      values = {LibC::ULong::MIN, LibC::ULong::MAX, LibC::ULongLong::MIN, LibC::ULongLong::MAX}
      print_error_to_s("%lu,%lu,%llu,%llu", *values).should eq(values.join(','))
      print_error_to_s("%lx,%lx,%llx,%llx", *values).should eq(values.join(',', &.to_s(16)))
    end
  end
end
