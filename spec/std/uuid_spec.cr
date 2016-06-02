require "spec"

describe "UUID" do
  it "can be built from strings" do
    UUID.new("c20335c3-7f46-4126-aae9-f665434ad12b").should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
    UUID.new("c20335c37f464126aae9f665434ad12b").should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
    UUID.new("C20335C3-7F46-4126-AAE9-F665434AD12B").should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
    UUID.new("C20335C37F464126AAE9F665434AD12B").should eq("c20335c3-7f46-4126-aae9-f665434ad12b")
  end

  it "compares to strings" do
    uuid = UUID.new "c3b46146eb794e18877b4d46a10d1517"
    ->{ uuid == "c3b46146eb794e18877b4d46a10d1517" }.call.should eq(true)
    ->{ uuid == "c3b46146-eb79-4e18-877b-4d46a10d1517" }.call.should eq(true)
    ->{ uuid == "C3B46146-EB79-4E18-877B-4D46A10D1517" }.call.should eq(true)
    ->{ UUID.new == "C3B46146-EB79-4E18-877B-4D46A10D1517" }.call.should eq(false)
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
end
