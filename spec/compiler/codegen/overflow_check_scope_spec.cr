require "../../spec_helper"

def checked_run(code)
  run(code, overflow_check: Crystal::OverflowCheckScope::Policy::Checked)
end

def unchecked_run(code)
  run(code, overflow_check: Crystal::OverflowCheckScope::Policy::Unchecked)
end

describe "Code gen: overflow check scope" do
  describe "for add" do
    it "can be unchecked" do
      checked_run(%(
        unchecked { 2147483647_i32 + 1_i32 }
      )).to_i.should eq(-2147483648_i32)
    end

    it "can be checked " do
      unchecked_run(%(
        require "prelude"

        x = 0
        begin
          checked { 2147483647_i32 + 1_i32 }
          x = 1
        rescue OverflowError
          x = 2
        end
        x
      )).to_i.should eq(2)
    end

    {% for type in [UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64] %}
      it "wrap around if unchecked for {{type}}" do
        unchecked_run(%(
          require "prelude"
          {{type}}::MAX + {{type}}.new(1) == {{type}}::MIN
        )).to_b.should be_true
      end

      it "raises if checked for {{type}}" do
        checked_run(%(
          require "prelude"
          begin
            {{type}}::MAX + {{type}}.new(1)
            0
          rescue OverflowError
            1
          end
        )).to_i.should eq(1)
      end

      it "wrap around if unchecked for {{type}} + Int64" do
        unchecked_run(%(
          require "prelude"
          {{type}}::MAX + 1_i64 == {{type}}::MIN
        )).to_b.should be_true
      end

      it "raises if checked for {{type}} + Int64" do
        checked_run(%(
          require "prelude"
          begin
            {{type}}::MAX + 1_i64
            0
          rescue OverflowError
            1
          end
        )).to_i.should eq(1)
      end
    {% end %}
  end

  it "obey default checked" do
    checked_run(%(
      require "prelude"

      x = 0
      begin
        a = 2147483647_i32 + 1_i32
        x = 1
      rescue OverflowError
        x = 2
      end
      x
    )).to_i.should eq(2)
  end

  it "obey default unchecked" do
    unchecked_run(%(
      2147483647_i32 + 1_i32
    )).to_i.should eq(-2147483648_i32)
  end

  it "is obeyed in return" do
    checked_run(%(
      def inc(v)
        unchecked {
          return v + 1_i8
        }
      end

      inc(127_i8)
    )).to_i.should eq(-128)
  end

  it "can be nested" do
    unchecked_run(%(
      require "prelude"

      begin
        checked { unchecked { 2147483647_i32 + 1_i32 } + 2147483647_i32 + 2147483647_i32 + 2_i32 }
        0
      rescue OverflowError
        1
      end
    )).to_i.should eq(1)
  end
end
