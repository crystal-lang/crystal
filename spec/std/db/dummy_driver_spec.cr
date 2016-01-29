require "spec"
require "db"
require "./dummy_driver"

describe DummyDriver do
  it "should return statements" do
    get_dummy.prepare("the query").should be_a(DB::Statement)
  end

  describe DummyDriver::DummyStatement do
    it "exec should return a result_set" do
      statement = get_dummy.prepare("a,b 1,2")
      result_set = statement.exec
      result_set.should be_a(DB::ResultSet)
      result_set.statement.should be(statement)
    end

    it "should enumerate records by spaces" do
      result_set = get_dummy.prepare("").exec
      result_set.move_next.should be_false

      result_set = get_dummy.prepare("a,b").exec
      result_set.move_next.should be_true
      result_set.move_next.should be_false

      result_set = get_dummy.prepare("a,b 1,2").exec
      result_set.move_next.should be_true
      result_set.move_next.should be_true
      result_set.move_next.should be_false

      result_set = get_dummy.prepare("a,b 1,2 c,d").exec
      result_set.move_next.should be_true
      result_set.move_next.should be_true
      result_set.move_next.should be_true
      result_set.move_next.should be_false
    end

    it "should enumerate string fields" do
      result_set = get_dummy.prepare("a,b 1,2").exec
      result_set.move_next
      result_set.read(String).should eq("a")
      result_set.read(String).should eq("b")
      result_set.move_next
      result_set.read(String).should eq("1")
      result_set.read(String).should eq("2")
    end

    it "should enumerate nil fields" do
      result_set = get_dummy.prepare("a,NULL 1,NULL").exec
      result_set.move_next
      result_set.read?(String).should eq("a")
      result_set.read?(String).should be_nil
      result_set.move_next
      result_set.read?(Int64).should eq(1)
      result_set.read?(Int64).should be_nil
    end

    it "should enumerate int64 fields" do
      result_set = get_dummy.prepare("3,4 1,2").exec
      result_set.move_next
      result_set.read(Int64).should eq(3i64)
      result_set.read(Int64).should eq(4i64)
      result_set.move_next
      result_set.read(Int64).should eq(1i64)
      result_set.read(Int64).should eq(2i64)
    end

    it "should enumerate blob fields" do
      result_set = get_dummy.prepare("az,AZ").exec
      result_set.move_next
      ary = [97u8, 122u8]
      result_set.read(Slice(UInt8)).should eq(Slice.new(ary.to_unsafe, ary.size))
      ary = [65u8, 90u8]
      result_set.read(Slice(UInt8)).should eq(Slice.new(ary.to_unsafe, ary.size))
    end

    it "should enumerate records using each" do
      nums = [] of Int32
      result_set = get_dummy.prepare("3,4 1,2").exec
      result_set.each do
        nums << result_set.read(Int32)
        nums << result_set.read(Int32)
      end

      nums.should eq([3, 4, 1, 2])
    end

    {% for value in [1, 1_i64, "hello", 1.5, 1.5_f32] %}
      it "should set arguments for {{value.id}}" do
        result_set = get_dummy.exec "?", {{value}}
        result_set.move_next.should be_true
        result_set.read(typeof({{value}})).should eq({{value}})
      end

      it "should set arguments by symbol for {{value.id}}" do
        result_set = get_dummy.exec ":once :twice", {once: {{value}}, twice: {{value + value}} }
        result_set.move_next.should be_true
        result_set.read(typeof({{value}})).should eq({{value}})
        result_set.move_next.should be_true
        result_set.read(typeof({{value}})).should eq({{value + value}})
      end

      it "should set arguments by string for {{value.id}}" do
        result_set = get_dummy.exec ":once :twice", {"once": {{value}}, "twice": {{value + value}} }
        result_set.move_next.should be_true
        result_set.read(typeof({{value}})).should eq({{value}})
        result_set.move_next.should be_true
        result_set.read(typeof({{value}})).should eq({{value + value}})
      end
    {% end %}

    it "executes and selects blob" do
      ary = UInt8[0x53, 0x51, 0x4C]
      slice = Slice.new(ary.to_unsafe, ary.size)
      result_set = get_dummy.exec "?", slice
      result_set.move_next
      result_set.read(Slice(UInt8)).to_a.should eq(ary)
    end
  end
end
