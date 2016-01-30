require "spec"
require "db"
require "./dummy_driver"

describe DummyDriver do
  it "with_dummy executes the block with a database" do
    with_witness do |w|
      with_dummy do |db|
        w.check
        db.should be_a(DB::Database)
      end
    end
  end

  describe DummyDriver::DummyStatement do
    it "should enumerate split rows by spaces" do
      with_dummy do |db|
        rs = db.query("")
        rs.move_next.should be_false
        rs.close

        rs = db.query("a,b")
        rs.move_next.should be_true
        rs.move_next.should be_false
        rs.close

        rs = db.query("a,b 1,2")
        rs.move_next.should be_true
        rs.move_next.should be_true
        rs.move_next.should be_false
        rs.close

        rs = db.query("a,b 1,2 c,d")
        rs.move_next.should be_true
        rs.move_next.should be_true
        rs.move_next.should be_true
        rs.move_next.should be_false
        rs.close
      end
    end

    it "should query with block shuold executes always" do
      with_witness do |w|
        with_dummy do |db|
          db.query "" do |rs|
            w.check
          end
        end
      end

      with_witness do |w|
        with_dummy do |db|
          db.query "lorem ipsum" do |rs|
            w.check
          end
        end
      end
    end

    it "should enumerate string fields" do
      with_dummy do |db|
        db.query "a,b 1,2" do |rs|
          rs.move_next
          rs.read(String).should eq("a")
          rs.read(String).should eq("b")
          rs.move_next
          rs.read(String).should eq("1")
          rs.read(String).should eq("2")
        end
      end
    end

    it "should enumerate nil fields" do
      with_dummy do |db|
        db.query "a,NULL 1,NULL" do |rs|
          rs.move_next
          rs.read?(String).should eq("a")
          rs.read?(String).should be_nil
          rs.move_next
          rs.read?(Int64).should eq(1)
          rs.read?(Int64).should be_nil
        end
      end
    end

    it "should enumerate int64 fields" do
      with_dummy do |db|
        db.query "3,4 1,2" do |rs|
          rs.move_next
          rs.read(Int64).should eq(3i64)
          rs.read(Int64).should eq(4i64)
          rs.move_next
          rs.read(Int64).should eq(1i64)
          rs.read(Int64).should eq(2i64)
        end
      end
    end

    it "should enumerate blob fields" do
      with_dummy do |db|
        db.query("az,AZ") do |rs|
          rs.move_next
          ary = [97u8, 122u8]
          rs.read(Slice(UInt8)).should eq(Slice.new(ary.to_unsafe, ary.size))
          ary = [65u8, 90u8]
          rs.read(Slice(UInt8)).should eq(Slice.new(ary.to_unsafe, ary.size))
        end
      end
    end

    it "should get Int32 scalars by default" do
      with_dummy do |db|
        db.scalar("1").should be_a(Int32)
        db.scalar?("1").should be_a(Int32)
        db.scalar?("NULL").should be_nil
      end
    end

    it "should get String scalars" do
      with_dummy do |db|
        db.scalar(String, "foo").should eq("foo")
      end
    end

    {% for value in [1, 1_i64, "hello", 1.5, 1.5_f32] %}
      it "numeric scalars of type of {{value.id}} should return value or nil" do
        with_dummy do |db|
          db.scalar(typeof({{value}}), "#{{{value}}}").should eq({{value}})
          db.scalar?(typeof({{value}}), "#{{{value}}}").should eq({{value}})
          db.scalar?(typeof({{value}}), "NULL").should be_nil
        end
      end

      it "should set positional arguments for {{value.id}}" do
        with_dummy do |db|
          db.scalar(typeof({{value}}), "?", {{value}}).should eq({{value}})
        end
      end

      it "should set arguments by symbol for {{value.id}}" do
        with_dummy do |db|
          db.query ":once :twice", {once: {{value}}, twice: {{value + value}} } do |rs|
            rs.move_next.should be_true
            rs.read(typeof({{value}})).should eq({{value}})
            rs.move_next.should be_true
            rs.read(typeof({{value}})).should eq({{value + value}})
          end
        end
      end

      it "should set arguments by string for {{value.id}}" do
        with_dummy do |db|
          db.query ":once :twice", {"once": {{value}}, "twice": {{value + value}} } do |rs|
            rs.move_next.should be_true
            rs.read(typeof({{value}})).should eq({{value}})
            rs.move_next.should be_true
            rs.read(typeof({{value}})).should eq({{value + value}})
          end
        end
      end
    {% end %}

    it "executes and selects blob" do
      with_dummy do |db|
        ary = UInt8[0x53, 0x51, 0x4C]
        slice = Slice.new(ary.to_unsafe, ary.size)
        db.scalar(Slice(UInt8), "?", slice).to_a.should eq(ary)
      end
    end
  end
end
