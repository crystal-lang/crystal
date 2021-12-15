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

  it "normalizes unpacking with underscore" do
    assert_normalize <<-FROM, <<-TO
      foo do |(x, _), z|
      end
      FROM
      foo do |__temp_1, z|
        x, _ = __temp_1
      end
      TO
  end

  it "normalizes nested unpacking" do
    assert_normalize <<-FROM, <<-TO
      foo do |(a, (b, c))|
        1
      end
      FROM
      foo do |__temp_1|
        a, __temp_2 = __temp_1
        b, c = __temp_2
        1
      end
      TO
  end

  it "normalizes multiple nested unpackings" do
    assert_normalize <<-FROM, <<-TO
      foo do |(a, (b, (c, (d, e)), f))|
        1
      end
      FROM
      foo do |__temp_1|
        a, __temp_2 = __temp_1
        b, __temp_3, f = __temp_2
        c, __temp_4 = __temp_3
        d, e = __temp_4
        1
      end
      TO
  end

  it "normalizes unpacking with splat" do
    assert_normalize <<-FROM, <<-TO
      foo do |(x, *y, z)|
      end
      FROM
      foo do |__temp_1|
        x, *y, z = __temp_1
      end
      TO
  end
end
