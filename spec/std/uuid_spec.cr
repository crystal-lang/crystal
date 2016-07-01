require "spec"
require "uuid"

describe "UUID" do
  it "#initialize with no args" do
    expected_uuid = UUID.new

    # expected_uuid.variant.should eq UUID::Variant::RFC4122
    # expected_uuid.version.should eq 4_u8
  end

  it "#initialize from strings" do
    expected_uuid = UUID.new("c20335c3-7f46-4126-aae9-f665434ad12b")

    expected_uuid.should eq UUID.new("c20335c3-7f46-4126-aae9-f665434ad12b")
    expected_uuid.should eq UUID.new("C20335C3-7F46-4126-AAE9-F665434AD12B")
    expected_uuid.should eq UUID.new("c20335c37f464126aae9f665434ad12b")
    expected_uuid.should eq UUID.new("C20335C37F464126AAE9F665434AD12B")
    expected_uuid.should eq UUID.new("urn:uuid:c20335c3-7f46-4126-aae9-f665434ad12b")
  end

  # it "#initialize from array" do
  #   expected_uuid = UUID.new([0_u8, 1_u8, 2_u8, 3_u8, 4_u8, 5_u8, 6_u8, 7_u8,
  #                             8_u8, 9_u8, 10_u8, 11_u8, 12_u8, 13_u8, 14_u8, 15_u8])

  #   # expected_uuid.variant.should eq UUID::Variant::RFC4122
  #   # expected_uuid.version.should eq 4_u8
  #   expected_uuid.to_s.should    eq "00010203-0405-0607-0809-0a0b0c0d0e0f"
  # end

  # it "#initialize has the correct version and variant" do
  #   expected_uuid = UUID.new

  #   expected_uuid.variant.should eq UUID::Variant::RFC4122
  #   expected_uuid.version.should eq 4_u8
  # end

  # it "#initialize with args has the correct version and variant" do
  #   expected_string_uuid = UUID.new("c20335c3-7f46-4126-aae9-f665434ad12b")

  #   expected_string_uuid.variant.should eq UUID::Variant::RFC4122
  #   expected_string_uuid.version.should eq 4_u8
  # end

  # it "#== with String" do end
  # it "#== with Array" do end
  # it "#to_a" do end
  # it "#to_s" do end
  # it "#to_s with format" do end

  # it "#version" do end
  # it "#version=" do end
  # it "#variant" do end
  # it "#variant=" do end

  # it "class level decodes to UUID" do
  #   expected_uuid = UUID.new("c20335c3-7f46-4126-aae9-f665434ad12b")

  #   expected_uuid.should eq UUID.decode("c20335c3-7f46-4126-aae9-f665434ad12b")
  #   expected_uuid.should eq UUID.decode("c20335c37f464126aae9f665434ad12b")
  #   expected_uuid.should eq UUID.decode("urn:uuid:c20335c3-7f46-4126-aae9-f665434ad12b")
  # end

  # it "#decodes to UUID" do
  #   expected_uuid = UUID.new("c20335c3-7f46-4126-aae9-f665434ad12b")

  #   actual_hypenated_uuid = UUID.new
  #   actual_hexstring_uuid = UUID.new
  #   actual_urn_uuid = UUID.new

  #   expected_uuid.should eq actual_hypenated_uuid.decode("c20335c3-7f46-4126-aae9-f665434ad12b")
  #   expected_uuid.should eq actual_hexstring_uuid.decode("c20335c37f464126aae9f665434ad12b")
  #   expected_uuid.should eq actual_urn_uuid.decode("urn:uuid:c20335c3-7f46-4126-aae9-f665434ad12b")
  # end

  # it "#encodes to string in different formats" do
  #   expected_uuid = UUID.new("c20335c3-7f46-4126-aae9-f665434ad12b")

  #   expected_uuid.encode.should              eq "c20335c3-7f46-4126-aae9-f665434ad12b"
  #   expected_uuid.encode(:hyphenated).should eq "c20335c3-7f46-4126-aae9-f665434ad12b"
  #   expected_uuid.encode(:hexstring).should  eq "c20335c37f464126aae9f665434ad12b"
  #   expected_uuid.encode(:urn).should        eq "urn:uuid:c20335c3-7f46-4126-aae9-f665434ad12b"
  # end
end
