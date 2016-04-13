require "../../spec_helper"

describe "Code gen: implicit type conversions" do
  it "codegens 'Int32 + Int64' (#567)" do
    run("1_i32 + 2147483647_i64 == 2147483648_i64").to_b.should be_true
  end

  it "codegens 'UInt32 + Int64'" do
    run("1_u32 + 2147483647_i64 == 2147483648_i64").to_b.should be_true
  end

  it "codegens 'UInt32 + UInt64'" do
    run("1_u32 + 2147483647_u64 == 2147483648_u64").to_b.should be_true
  end

  it "codegens (Int32 + Int64).is_a?(Int64)" do
    run("(1 + 2147483647_i64).is_a?(Int64)").to_b.should be_true
  end

  it "codegens (Int32 - Int64).is_a?(Int64)" do
    run("(1 - 2147483647_i64).is_a?(Int64)").to_b.should be_true
  end

  it "codegens (Int32 * Int64).is_a?(Int64)" do
    run("(1 * 2147483647_i64).is_a?(Int64)").to_b.should be_true
  end

  it "codegens (Int32 | Int64).is_a?(Int64)" do
    run("(1 | 2147483647_i64).is_a?(Int64)").to_b.should be_true
  end

  it "codegens (Int32 & Int64).is_a?(Int64)" do
    run("(1 & 2147483647_i64).is_a?(Int64)").to_b.should be_true
  end

  it "codegens (Int32 ^ Int64).is_a?(Int64)" do
    run("(1 ^ 2147483647_i64).is_a?(Int64)").to_b.should be_true
  end
end
