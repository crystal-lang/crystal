require "../../spec_helper"

describe "Normalize: block" do
  it "normalizes unpacking with empty body" do
    assert_normalize <<-FROM, <<-TO
      foo do |(x, y), z|
      end
      FROM
      foo do |__temp_1, z|
        x, y = __temp_1
      end
      TO
  end

  it "normalizes unpacking with single expression body" do
    assert_normalize <<-FROM, <<-TO
      foo do |(x, y), z|
        z
      end
      FROM
      foo do |__temp_1, z|
        x, y = __temp_1
        z
      end
      TO
  end

  it "normalizes unpacking with multiple body expressions" do
    assert_normalize <<-FROM, <<-TO
      foo do |(x, y), z|
        x
        y
        z
      end
      FROM
      foo do |__temp_1, z|
        x, y = __temp_1
        x
        y
        z
      end
      TO
  end
end
