require "spec"

enum SpecEnum
  One
  Two
  Three
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

  it "has hash" do
    SpecEnum::Two.hash.should eq(1.hash)
  end
end
