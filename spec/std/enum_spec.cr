require "spec"

enum SpecEnum : Int8
  One
  Two
  Three
end

enum SpecEnum2
  FourtyTwo
  FOURTY_FOUR
end

@[Flags]
enum SpecEnumFlags
  One
  Two
  Three
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
      SpecEnumFlags::All.to_s.should eq("One, Two, Three")
      (SpecEnumFlags::One | SpecEnumFlags::Two).to_s.should eq("One, Two")
    end
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
      SpecEnumFlags.from_value?(0).should be_nil
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
      expect_raises { SpecEnum.from_value(3) }
    end

    it "for flags enum" do
      expect_raises { SpecEnumFlags.from_value(0) }
      SpecEnumFlags.from_value(1).should eq(SpecEnumFlags::One)
      SpecEnumFlags.from_value(2).should eq(SpecEnumFlags::Two)
      SpecEnumFlags.from_value(3).should eq(SpecEnumFlags::One | SpecEnumFlags::Two)
    end
  end

  it "has hash" do
    SpecEnum::Two.hash.should eq(1.hash)
  end

  it "parses" do
    SpecEnum.parse("Two").should eq(SpecEnum::Two)
    SpecEnum2.parse("FourtyTwo").should eq(SpecEnum2::FourtyTwo)
    SpecEnum2.parse("fourty_two").should eq(SpecEnum2::FourtyTwo)
    expect_raises(ArgumentError, "Unknown enum SpecEnum value: Four") { SpecEnum.parse("Four") }

    SpecEnum.parse("TWO").should eq(SpecEnum::Two)
    SpecEnum.parse("TwO").should eq(SpecEnum::Two)
    SpecEnum2.parse("FOURTY_TWO").should eq(SpecEnum2::FourtyTwo)

    SpecEnum2.parse("FOURTY_FOUR").should eq(SpecEnum2::FOURTY_FOUR)
    SpecEnum2.parse("fourty_four").should eq(SpecEnum2::FOURTY_FOUR)
    SpecEnum2.parse("FourtyFour").should eq(SpecEnum2::FOURTY_FOUR)
    SpecEnum2.parse("FOURTYFOUR").should eq(SpecEnum2::FOURTY_FOUR)
    SpecEnum2.parse("fourtyfour").should eq(SpecEnum2::FOURTY_FOUR)
  end

  it "parses?" do
    SpecEnum.parse?("Two").should eq(SpecEnum::Two)
    SpecEnum.parse?("Four").should be_nil
  end

  it "clones" do
    SpecEnum::One.clone.should eq(SpecEnum::One)
  end
end
