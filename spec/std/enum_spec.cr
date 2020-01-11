require "spec"

enum SpecEnum : Int8
  One
  Two
  Three
end

enum SpecEnum2
  FortyTwo
  FORTY_FOUR
end

@[Flags]
enum SpecEnumFlags
  One
  Two
  Three
end

enum SpecBigEnum : Int64
  TooBig = 4294967296i64 # == 2**32
end

describe Enum do
  describe "to_s" do
    it "for simple enum" do
      SpecEnum::One.to_s.should eq("One")
      SpecEnum::Two.to_s.should eq("Two")
      SpecEnum::Three.to_s.should eq("Three")
    end

    it "for flags enum" do
      SpecEnumFlags::None.to_s.should eq("None")
      SpecEnumFlags::All.to_s.should eq("One | Two | Three")
      (SpecEnumFlags::One | SpecEnumFlags::Two).to_s.should eq("One | Two")
    end
  end

  it "creates an enum instance from an auto-casted symbol (#8573)" do
    enum_value = SpecEnum.new(:two)
    enum_value.should eq SpecEnum::Two
  end

  it "gets value" do
    SpecEnum::Two.value.should eq(1)
    SpecEnum::Two.value.should be_a(Int8)
  end

  it "gets value with to_i" do
    SpecEnum::Two.to_i.should eq(1)
    SpecEnum::Two.to_i.should be_a(Int32)

    SpecEnum::Two.to_i64.should eq(1)
    SpecEnum::Two.to_i64.should be_a(Int64)
  end

  it "does +" do
    (SpecEnum::One + 1).should eq(SpecEnum::Two)
  end

  it "does -" do
    (SpecEnum::Two - 1).should eq(SpecEnum::One)
  end

  it "sorts" do
    [SpecEnum::Three, SpecEnum::One, SpecEnum::Two].sort.should eq([SpecEnum::One, SpecEnum::Two, SpecEnum::Three])
  end

  it "does includes?" do
    (SpecEnumFlags::One | SpecEnumFlags::Two).includes?(SpecEnumFlags::One).should be_true
    (SpecEnumFlags::One | SpecEnumFlags::Two).includes?(SpecEnumFlags::Three).should be_false
  end

  describe "each" do
    it "won't yield None" do
      SpecEnumFlags::None.each do |name|
        raise "unexpected yield"
      end
    end

    it "won't yield All" do
      SpecEnumFlags::All.each do |name|
        raise "unexpected yield" if name == SpecEnumFlags::All
      end
    end

    it "yields each member" do
      names = [] of SpecEnumFlags
      values = [] of Int32
      SpecEnumFlags.flags(One, Three).each do |name, value|
        names << name
        values << value
      end
      names.should eq([SpecEnumFlags::One, SpecEnumFlags::Three])
      values.should eq([SpecEnumFlags::One.value, SpecEnumFlags::Three.value])
    end
  end

  describe "names" do
    it "for simple enum" do
      SpecEnum.names.should eq(%w(One Two Three))
    end

    it "for flags enum" do
      SpecEnumFlags.names.should eq(%w(One Two Three))
    end
  end

  describe "values" do
    it "for simple enum" do
      SpecEnum.values.should eq([SpecEnum::One, SpecEnum::Two, SpecEnum::Three])
    end

    it "for flags enum" do
      SpecEnumFlags.values.should eq([SpecEnumFlags::One, SpecEnumFlags::Two, SpecEnumFlags::Three])
    end
  end

  describe "from_value?" do
    it "for simple enum" do
      SpecEnum.from_value?(0).should eq(SpecEnum::One)
      SpecEnum.from_value?(1).should eq(SpecEnum::Two)
      SpecEnum.from_value?(2).should eq(SpecEnum::Three)
      SpecEnum.from_value?(3).should be_nil
    end

    it "for flags enum" do
      SpecEnumFlags.from_value?(0).should eq(SpecEnumFlags::None)
      SpecEnumFlags.from_value?(1).should eq(SpecEnumFlags::One)
      SpecEnumFlags.from_value?(2).should eq(SpecEnumFlags::Two)
      SpecEnumFlags.from_value?(3).should eq(SpecEnumFlags::One | SpecEnumFlags::Two)
      SpecEnumFlags.from_value?(8).should be_nil
    end
  end

  describe "from_value" do
    it "for simple enum" do
      SpecEnum.from_value(0).should eq(SpecEnum::One)
      SpecEnum.from_value(1).should eq(SpecEnum::Two)
      SpecEnum.from_value(2).should eq(SpecEnum::Three)
      expect_raises(Exception, "Unknown enum SpecEnum value: 3") { SpecEnum.from_value(3) }
    end

    it "for flags enum" do
      SpecEnumFlags.from_value(0).should eq(SpecEnumFlags::None)
      SpecEnumFlags.from_value(1).should eq(SpecEnumFlags::One)
      SpecEnumFlags.from_value(2).should eq(SpecEnumFlags::Two)
      SpecEnumFlags.from_value(3).should eq(SpecEnumFlags::One | SpecEnumFlags::Two)
      expect_raises(Exception, "Unknown enum SpecEnumFlags value: 8") { SpecEnumFlags.from_value(8) }
    end
  end

  describe "valid?" do
    it "for simple enum" do
      SpecEnum.valid?(SpecEnum::One).should be_true
      SpecEnum.valid?(SpecEnum::Two).should be_true
      SpecEnum.valid?(SpecEnum::Three).should be_true
      SpecEnum.valid?(SpecEnum.new(3i8)).should be_false
    end

    it "for flags enum" do
      SpecEnumFlags.valid?(SpecEnumFlags::One).should be_true
      SpecEnumFlags.valid?(SpecEnumFlags::Two).should be_true
      SpecEnumFlags.valid?(SpecEnumFlags::One | SpecEnumFlags::Two).should be_true
      SpecEnumFlags.valid?(SpecEnumFlags.new(8)).should be_false
      SpecEnumFlags.valid?(SpecEnumFlags::None).should be_true
      SpecEnumFlags.valid?(SpecEnumFlags::All).should be_true
    end

    it "for Int64 enum" do
      SpecBigEnum.valid?(SpecBigEnum::TooBig).should be_true
      SpecBigEnum.valid?(SpecBigEnum.new(0i64)).should be_false
    end
  end

  it "has hash" do
    SpecEnum::Two.hash.should_not eq(SpecEnum::Three.hash)
  end

  it "parses" do
    SpecEnum.parse("Two").should eq(SpecEnum::Two)
    SpecEnum2.parse("FortyTwo").should eq(SpecEnum2::FortyTwo)
    SpecEnum2.parse("forty_two").should eq(SpecEnum2::FortyTwo)
    expect_raises(ArgumentError, "Unknown enum SpecEnum value: Four") { SpecEnum.parse("Four") }

    SpecEnum.parse("TWO").should eq(SpecEnum::Two)
    SpecEnum.parse("TwO").should eq(SpecEnum::Two)
    SpecEnum2.parse("FORTY_TWO").should eq(SpecEnum2::FortyTwo)

    SpecEnum2.parse("FORTY_FOUR").should eq(SpecEnum2::FORTY_FOUR)
    SpecEnum2.parse("forty_four").should eq(SpecEnum2::FORTY_FOUR)
    SpecEnum2.parse("FortyFour").should eq(SpecEnum2::FORTY_FOUR)
    SpecEnum2.parse("FORTYFOUR").should eq(SpecEnum2::FORTY_FOUR)
    SpecEnum2.parse("fortyfour").should eq(SpecEnum2::FORTY_FOUR)
  end

  it "parses?" do
    SpecEnum.parse?("Two").should eq(SpecEnum::Two)
    SpecEnum.parse?("Four").should be_nil
  end

  it "clones" do
    SpecEnum::One.clone.should eq(SpecEnum::One)
  end

  describe "each" do
    it "iterates each member" do
      keys = [] of SpecEnum
      values = [] of Int8

      SpecEnum.each do |key, value|
        keys << key
        values << value
      end

      keys.should eq([SpecEnum::One, SpecEnum::Two, SpecEnum::Three])
      values.should eq([SpecEnum::One.value, SpecEnum::Two.value, SpecEnum::Three.value])
    end

    it "iterates each flag" do
      keys = [] of SpecEnumFlags
      values = [] of Int32

      SpecEnumFlags.each do |key, value|
        keys << key
        values << value
      end

      keys.should eq([SpecEnumFlags::One, SpecEnumFlags::Two, SpecEnumFlags::Three])
      values.should eq([SpecEnumFlags::One.value, SpecEnumFlags::Two.value, SpecEnumFlags::Three.value])
    end
  end

  it "different enums classes not eq always" do
    SpecEnum::One.should_not eq SpecEnum2::FortyTwo
  end
end
