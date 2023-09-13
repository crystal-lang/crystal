require "spec"
require "uuid"
require "spec/helpers/string"

describe "UUID" do
  describe "#==" do
    it "matches identical UUIDs" do
      UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93").should eq UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93")
      UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93").hash.should eq UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93").hash
    end
  end

  describe "#<=>" do
    it "correctly compares two UUIDs" do
      uuid_1 = UUID.new("00330000-0000-0000-0000-000000000000")
      uuid_2 = UUID.new("00000011-0000-0000-5500-000099000000")
      (uuid_1 <=> uuid_2).should be > 0
      (uuid_2 <=> uuid_1).should be < 0
      (uuid_1 <=> uuid_1).should eq 0
    end
  end

  describe "random initialize" do
    it "works with no options" do
      subject = UUID.random
      subject.variant.should eq UUID::Variant::RFC4122
      subject.version.should eq UUID::Version::V4
    end

    it "does inspect" do
      subject = UUID.random
      subject.inspect.should eq "UUID(#{subject})"
    end

    it "works with variant" do
      subject = UUID.random(variant: UUID::Variant::NCS)
      subject.variant.should eq UUID::Variant::NCS
      subject.version.should eq UUID::Version::V4
    end

    it "works with version" do
      subject = UUID.random(version: UUID::Version::V3)
      subject.variant.should eq UUID::Variant::RFC4122
      subject.version.should eq UUID::Version::V3
    end
  end

  describe "initialize from static array" do
    it "works with static array only" do
      subject = UUID.new(StaticArray(UInt8, 16).new(0_u8))
      subject.to_s.should eq "00000000-0000-0000-0000-000000000000"
    end

    it "works with static array and variant" do
      subject = UUID.new(StaticArray(UInt8, 16).new(0_u8), variant: UUID::Variant::RFC4122)
      subject.to_s.should eq "00000000-0000-0000-8000-000000000000"
      subject.variant.should eq UUID::Variant::RFC4122
    end

    it "works with static array and version" do
      subject = UUID.new(StaticArray(UInt8, 16).new(0_u8), version: UUID::Version::V3)
      subject.to_s.should eq "00000000-0000-3000-0000-000000000000"
      subject.version.should eq UUID::Version::V3
    end

    it "works with static array, variant and version" do
      subject = UUID.new(StaticArray(UInt8, 16).new(0_u8), variant: UUID::Variant::Microsoft, version: UUID::Version::V3)
      subject.to_s.should eq "00000000-0000-3000-c000-000000000000"
      subject.variant.should eq UUID::Variant::Microsoft
      subject.version.should eq UUID::Version::V3
    end
  end

  it "initializes with slice" do
    subject = UUID.new(Slice(UInt8).new(16, 0_u8), variant: UUID::Variant::RFC4122, version: UUID::Version::V4)
    subject.to_s.should eq "00000000-0000-4000-8000-000000000000"
    subject.variant.should eq UUID::Variant::RFC4122
    subject.version.should eq UUID::Version::V4
  end

  describe "initialize with String" do
    it "works with string only" do
      subject = UUID.new("00000000-0000-0000-0000-000000000000")
      subject.to_s.should eq "00000000-0000-0000-0000-000000000000"
    end

    it "works with string and variant" do
      subject = UUID.new("00000000-0000-0000-0000-000000000000", variant: UUID::Variant::Future)
      subject.to_s.should eq "00000000-0000-0000-e000-000000000000"
      subject.variant.should eq UUID::Variant::Future
    end

    it "works with string and version" do
      subject = UUID.new("00000000-0000-0000-0000-000000000000", version: UUID::Version::V5)
      subject.to_s.should eq "00000000-0000-5000-0000-000000000000"
      subject.version.should eq UUID::Version::V5
    end

    it "can be built from strings" do
      UUID.new("c20335c3-7f46-4126-aae9-f665434ad12b").to_s.should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
      UUID.new("c20335c37f464126aae9f665434ad12b").to_s.should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
      UUID.new("C20335C3-7F46-4126-AAE9-F665434AD12B").to_s.should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
      UUID.new("C20335C37F464126AAE9F665434AD12B").to_s.should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
      UUID.new("urn:uuid:1ed1ee2f-ef9a-4f9c-9615-ab14d8ef2892").to_s.should eq("1ed1ee2f-ef9a-4f9c-9615-ab14d8ef2892")
    end
  end

  describe "parsing strings" do
    it "returns a properly parsed UUID" do
      UUID.parse?("c20335c3-7f46-4126-aae9-f665434ad12b").to_s.should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
    end

    it "returns nil if it has the wrong number of characters" do
      UUID.parse?("nope").should eq nil
    end

    it "returns nil if it has incorrect characters" do
      UUID.parse?("c20335c3-7f46-4126-aae9-f665434ad12?").should eq nil
      UUID.parse?("lol!wut?-asdf-fork-typo-omglolwtfbbq").should eq nil
      UUID.parse?("lol!wut?asdfforktypoomglolwtfbbq").should eq nil
      UUID.parse?("urn:uuid:lol!wut?-asdf-fork-typo-omglolwtfbbq").should eq nil
    end
  end

  it "initializes from UUID" do
    uuid = UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93")
    uuid = UUID.new(uuid, version: UUID::Version::V2, variant: UUID::Variant::Microsoft)
    uuid.version.should eq UUID::Version::V2
    uuid.variant.should eq UUID::Variant::Microsoft
    uuid.bytes.should eq(UInt8.static_array(80, 161, 29, 166, 55, 123, 43, 223, 217, 240, 7, 111, 157, 182, 28, 147))
    uuid.to_s.should eq "50a11da6-377b-2bdf-d9f0-076f9db61c93"
  end

  it "initializes zeroed UUID" do
    UUID.empty.should eq UUID.new(StaticArray(UInt8, 16).new(0_u8), UUID::Variant::NCS, UUID::Version::V4)
    UUID.empty.to_s.should eq "00000000-0000-4000-0000-000000000000"
    UUID.empty.variant.should eq UUID::Variant::NCS
    UUID.empty.version.should eq UUID::Version::V4
  end

  describe "supports different string formats" do
    it "normal output" do
      assert_prints UUID.new("ee843b2656d8472bb3430b94ed9077ff").to_s, "ee843b26-56d8-472b-b343-0b94ed9077ff"
    end

    it "hexstring" do
      UUID.new("3e806983-eca4-4fc5-b581-f30fb03ec9e5").hexstring.should eq "3e806983eca44fc5b581f30fb03ec9e5"
    end

    it "urn" do
      UUID.new("1ed1ee2f-ef9a-4f9c-9615-ab14d8ef2892").urn.should eq "urn:uuid:1ed1ee2f-ef9a-4f9c-9615-ab14d8ef2892"
    end
  end

  it "fails on invalid arguments when creating" do
    expect_raises(ArgumentError) { UUID.new "25d6f843?cf8e-44fb-9f84-6062419c4330" }
    expect_raises(ArgumentError) { UUID.new "67dc9e24-0865 474b-9fe7-61445bfea3b5" }
    expect_raises(ArgumentError) { UUID.new "5942cde5-10d1-416b+85c4-9fc473fa1037" }
    expect_raises(ArgumentError) { UUID.new "0f02a229-4898-4029-926f=94be5628a7fd" }
    expect_raises(ArgumentError) { UUID.new "cda08c86-6413-474f-8822-a6646e0fb19G" }
    expect_raises(ArgumentError) { UUID.new "2b1bfW06368947e59ac07c3ffdaf514c" }
    expect_raises(ArgumentError) { UUID.new "xyz:uuid:1ed1ee2f-ef9a-4f9c-9615-ab14d8ef2892" }
  end

  describe "v4?" do
    it "returns true if UUID is v4, false otherwise" do
      uuid = UUID.random
      uuid.v4?.should eq(true)
      uuid = UUID.new("00000000-0000-0000-0000-000000000000", version: UUID::Version::V5)
      uuid.v4?.should eq(false)
    end
  end

  describe "v4!" do
    it "returns true if UUID is v4, raises otherwise" do
      uuid = UUID.random
      uuid.v4!.should eq(true)
      uuid = UUID.new("00000000-0000-0000-0000-000000000000", version: UUID::Version::V5)
      expect_raises(UUID::Error) { uuid.v4! }
    end
  end
end
