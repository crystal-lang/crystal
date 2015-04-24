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
      expect(SpecEnum::One.to_s).to eq("One")
      expect(SpecEnum::Two.to_s).to eq("Two")
      expect(SpecEnum::Three.to_s).to eq("Three")
    end

    it "for flags enum" do
      expect(SpecEnumFlags::None.to_s).to eq("None")
      expect(SpecEnumFlags::All.to_s).to eq("One, Two, Three")
      expect((SpecEnumFlags::One | SpecEnumFlags::Two).to_s).to eq("One, Two")
    end
  end

  it "does +" do
    expect((SpecEnum::One + 1)).to eq(SpecEnum::Two)
  end

  it "does -" do
    expect((SpecEnum::Two - 1)).to eq(SpecEnum::One)
  end

  it "sorts" do
    expect([SpecEnum::Three, SpecEnum::One, SpecEnum::Two].sort).to eq([SpecEnum::One, SpecEnum::Two, SpecEnum::Three])
  end

  it "does includes?" do
    expect((SpecEnumFlags::One | SpecEnumFlags::Two).includes?(SpecEnumFlags::One)).to be_true
    expect((SpecEnumFlags::One | SpecEnumFlags::Two).includes?(SpecEnumFlags::Three)).to be_false
  end

  describe "names" do
    it "for simple enum" do
      expect(SpecEnum.names).to eq(%w(One Two Three))
    end

    it "for flags enum" do
      expect(SpecEnumFlags.names).to eq(%w(One Two Three))
    end
  end

  describe "values" do
    it "for simple enum" do
      expect(SpecEnum.values).to eq([SpecEnum::One, SpecEnum::Two, SpecEnum::Three])
    end

    it "for flags enum" do
      expect(SpecEnumFlags.values).to eq([SpecEnumFlags::One, SpecEnumFlags::Two, SpecEnumFlags::Three])
    end
  end

  it "has hash" do
    expect(SpecEnum::Two.hash).to eq(1.hash)
  end

  it "parses" do
    expect(SpecEnum.parse("Two")).to eq(SpecEnum::Two)
    expect_raises(Exception, "Unknown enum SpecEnum value: Four") { SpecEnum.parse("Four") }
  end

  it "parses?" do
    expect(SpecEnum.parse?("Two")).to eq(SpecEnum::Two)
    expect(SpecEnum.parse?("Four")).to be_nil
  end
end
