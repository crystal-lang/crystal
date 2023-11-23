require "spec"

describe String::Builder do
  it "builds" do
    str = String::Builder.build do |builder|
      builder << 123
      builder << 456
    end
    str.should eq("123456")
  end

  it "raises if invokes to_s twice" do
    builder = String::Builder.new
    builder << 123
    builder.to_s.should eq("123")

    expect_raises(Exception, "Can only invoke 'to_s' once on String::Builder") { builder.to_s }
  end

  it "goes back" do
    s = String::Builder.build do |str|
      str << 12
      str.back(1)
    end
    s.should eq("1")
  end

  it "goes back all" do
    s = String::Builder.build do |str|
      str << 12
      str.back(2)
    end
    s.should eq("")
  end

  describe "#chomp!" do
    it "returns self" do
      str = String::Builder.new
      str << "a,b,c,"
      str.chomp!(44).to_s.should eq("a,b,c")
    end
  end

  it "raises EOFError" do
    builder = String::Builder.new
    initial_capacity = builder.capacity
    expect_raises(IO::EOFError) do
      builder.write Slice.new(Pointer(UInt8).null, Int32::MAX)
    end
    # nothing get's written
    builder.bytesize.should eq 0
    builder.capacity.should eq initial_capacity
  end

  it "allocates for > 1 GB", tags: %w[slow], focus: true do
    Crystal::System.print_error "start test\n"
    String::Builder.build do |str|
      Crystal::System.print_error "start block\n"
      mbstring = "a" * 1024 * 1024
      Crystal::System.print_error "allocated mbstring\n"
      1023.times { str << mbstring }
      Crystal::System.print_error "wrote 999 MB\n"

      str.bytesize.should eq (1 << 30) - (1 << 20)
      str.capacity.should eq 1 << 30
      Crystal::System.print_error "tested bytesize and capacity\n"

      str << mbstring

      Crystal::System.print_error "wrote another MB\n"

      str.bytesize.should eq 1 << 30
      str.capacity.should eq Int32::MAX
      Crystal::System.print_error "tested bytesize and capacity\n"

      1023.times { str << mbstring }
      Crystal::System.print_error "wrote 999 MB\n"

      # FIXME: https://github.com/crystal-lang/crystal/actions/runs/6895836942/job/18764260201?pr=13989
      {% unless flag?(:wasm32) %}
        str.write mbstring.to_slice[0..(-4 - String::HEADER_SIZE)]
        Crystal::System.print_error "wrote almost 1 MB\n"
        str << "a"
        Crystal::System.print_error "wrote last byte\n"
        expect_raises(IO::EOFError) do
          str << "a"
        end
      {% end %}
      Crystal::System.print_error "end block\n"
    end
    Crystal::System.print_error "end test\n"
  end
end
