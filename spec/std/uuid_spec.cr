require "spec"
require "uuid"

describe "UUID" do
  it "has working zero UUID" do
    UUID.empty.should eq UUID.new(StaticArray(UInt8, 16).new(0_u8))
    UUID.empty.to_s.should eq "00000000-0000-0000-0000-000000000000"
    UUID.empty.variant.should eq UUID::Variant::NCS
  end

  it "can be built from strings" do
    UUID.new("c20335c3-7f46-4126-aae9-f665434ad12b").should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
    UUID.new("c20335c37f464126aae9f665434ad12b").should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
    UUID.new("C20335C3-7F46-4126-AAE9-F665434AD12B").should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
    UUID.new("C20335C37F464126AAE9F665434AD12B").should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
  end

  it "should have correct variant and version" do
    UUID.new("C20335C37F464126AAE9F665434AD12B").variant.should eq UUID::Variant::RFC4122
    UUID.new("C20335C37F464126AAE9F665434AD12B").version.should eq UUID::Version::V4
  end

  it "supports different string formats" do
    UUID.new("ee843b2656d8472bb3430b94ed9077ff").to_s.should eq "ee843b26-56d8-472b-b343-0b94ed9077ff"
    UUID.new("3e806983-eca4-4fc5-b581-f30fb03ec9e5").hexstring.should eq "3e806983eca44fc5b581f30fb03ec9e5"
    UUID.new("1ed1ee2f-ef9a-4f9c-9615-ab14d8ef2892").urn.should eq "urn:uuid:1ed1ee2f-ef9a-4f9c-9615-ab14d8ef2892"
  end

  it "compares to strings" do
    uuid = UUID.new "c3b46146eb794e18877b4d46a10d1517"
    uuid.should eq("c3b46146eb794e18877b4d46a10d1517")
    uuid.should eq("c3b46146-eb79-4e18-877b-4d46a10d1517")
    uuid.should eq("C3B46146-EB79-4E18-877B-4D46A10D1517")
    uuid.should eq("urn:uuid:C3B46146-EB79-4E18-877B-4D46A10D1517")
    uuid.should eq("urn:uuid:c3b46146-eb79-4e18-877b-4d46a10d1517")
    (UUID.new).should_not eq("C3B46146-EB79-4E18-877B-4D46A10D1517")
  end

  it "fails on invalid arguments when creating" do
    expect_raises(ArgumentError) { UUID.new "" }
    expect_raises(ArgumentError) { UUID.new "25d6f843?cf8e-44fb-9f84-6062419c4330" }
    expect_raises(ArgumentError) { UUID.new "67dc9e24-0865 474b-9fe7-61445bfea3b5" }
    expect_raises(ArgumentError) { UUID.new "5942cde5-10d1-416b+85c4-9fc473fa1037" }
    expect_raises(ArgumentError) { UUID.new "0f02a229-4898-4029-926f=94be5628a7fd" }
    expect_raises(ArgumentError) { UUID.new "cda08c86-6413-474f-8822-a6646e0fb19G" }
    expect_raises(ArgumentError) { UUID.new "2b1bfW06368947e59ac07c3ffdaf514c" }
  end

  it "fails when comparing to invalid strings" do
    expect_raises(ArgumentError) { UUID.new == "" }
    expect_raises(ArgumentError) { UUID.new == "d1fb9189-7013-4915-a8b1-07cfc83bca3U" }
    expect_raises(ArgumentError) { UUID.new == "2ab8ffc8f58749e197eda3e3d14e0 6c" }
    expect_raises(ArgumentError) { UUID.new == "2ab8ffc8f58749e197eda3e3d14e 06c" }
    expect_raises(ArgumentError) { UUID.new == "2ab8ffc8f58749e197eda3e3d14e-76c" }
  end

  it "should handle variant" do
    uuid = UUID.new
    expect_raises(ArgumentError) { uuid.variant = UUID::Variant::Unknown }
    {% for variant in %w(NCS RFC4122 Microsoft Future) %}
      uuid.variant = UUID::Variant::{{ variant.id }}
      uuid.variant.should eq UUID::Variant::{{ variant.id }}
    {% end %}
  end

  it "should handle version" do
    uuid = UUID.new
    expect_raises(ArgumentError) { uuid.version = UUID::Version::Unknown }
    {% for version in %w(1 2 3 4 5) %}
      uuid.version = UUID::Version::V{{ version.id }}
      uuid.version.should eq UUID::Version::V{{ version.id }}
    {% end %}
  end
end
