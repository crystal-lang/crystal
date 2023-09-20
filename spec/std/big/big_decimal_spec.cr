require "spec"
require "big"
require "spec/helpers/string"

describe BigDecimal do
  it "initializes from valid input" do
    BigDecimal.new
      .should eq(BigDecimal.new(BigInt.new(0)))

    BigDecimal.new("41.0123")
      .should eq(BigDecimal.new(BigInt.new(410123), 4))

    BigDecimal.new(1)
      .should eq(BigDecimal.new(BigInt.new(1)))

    BigDecimal.new(-1)
      .should eq(BigDecimal.new(BigInt.new(-1)))

    BigDecimal.new(0)
      .should eq(BigDecimal.new(BigInt.new(0)))

    BigDecimal.new("42.0123")
      .should eq(BigDecimal.new(BigInt.new(420123), 4))

    BigDecimal.new("42_42_42_24.0123_456_789")
      .should eq(BigDecimal.new(BigInt.new(424242240123456789), 10))

    BigDecimal.new("0.0")
      .should eq(BigDecimal.new(BigInt.new(0)))

    BigDecimal.new(".2")
      .should eq(BigDecimal.new(BigInt.new(2), 1))

    BigDecimal.new("2.")
      .should eq(BigDecimal.new(BigInt.new(2)))

    BigDecimal.new("-.2")
      .should eq(BigDecimal.new(BigInt.new(-2), 1))

    BigDecimal.new("-2.")
      .should eq(BigDecimal.new(BigInt.new(-2)))

    BigDecimal.new("-0.1")
      .should eq(BigDecimal.new(BigInt.new(-1), 1))

    BigDecimal.new("-1.1")
      .should eq(BigDecimal.new(BigInt.new(-11), 1))

    BigDecimal.new("123871293879123790874230984702938470917238971298379127390182739812739817239087123918273098.1029387192083710928371092837019283701982370918237")
      .should eq(BigDecimal.new(BigInt.new("1238712938791237908742309847029384709172389712983791273901827398127398172390871239182730981029387192083710928371092837019283701982370918237".to_big_i), 49))

    BigDecimal.new("-123871293879123790874230984702938470917238971298379127390182739812739817239087123918273098.1029387192083710928371092837019283701982370918237")
      .should eq(BigDecimal.new(BigInt.new("-1238712938791237908742309847029384709172389712983791273901827398127398172390871239182730981029387192083710928371092837019283701982370918237".to_big_i), 49))

    BigDecimal.new("-0.1029387192083710928371092837019283701982370918237")
      .should eq(BigDecimal.new(BigInt.new("-1029387192083710928371092837019283701982370918237".to_big_i), 49))

    BigDecimal.new("2")
      .should eq(BigDecimal.new(BigInt.new(2)))

    BigDecimal.new("-1")
      .should eq(BigDecimal.new(BigInt.new(-1)))

    BigDecimal.new("0")
      .should eq(BigDecimal.new(BigInt.new(0)))

    BigDecimal.new("-0")
      .should eq(BigDecimal.new(BigInt.new(0)))

    BigDecimal.new(BigDecimal.new(2))
      .should eq(BigDecimal.new(2.to_big_i))

    BigDecimal.new(BigRational.new(1, 2))
      .should eq(BigDecimal.new(BigInt.new(5), 1))
  end

  it "raises InvalidBigDecimalException when initializing from invalid input" do
    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("derp")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1.2.3")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("..2")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1..2")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("a1.2")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1a.2")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1.a2")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1.2a")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1ee1")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("e+e1")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1e1e")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1 e1")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("..e1")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("-..e1")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("e1")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("e+5")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new(".e1")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new(".e+1")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("-.e1")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1e.")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1e0.1")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1e+")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1.1e-")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("-")
    end

    expect_raises(InvalidBigDecimalException) do
      BigDecimal.new("1.0e")
    end
  end

  it "raises if creating from infinity" do
    expect_raises(ArgumentError, "Can only construct from a finite number") { BigDecimal.new(Float32::INFINITY) }
    expect_raises(ArgumentError, "Can only construct from a finite number") { BigDecimal.new(Float64::INFINITY) }
  end

  it "raises if creating from NaN" do
    expect_raises(ArgumentError, "Can only construct from a finite number") { BigDecimal.new(Float32::NAN) }
    expect_raises(ArgumentError, "Can only construct from a finite number") { BigDecimal.new(Float64::NAN) }
  end

  it "performs arithmetic with bigdecimals" do
    BigDecimal.new(0).should eq(BigDecimal.new(0) + BigDecimal.new(0))
    BigDecimal.new(1).should eq(BigDecimal.new(0) + BigDecimal.new(1))
    BigDecimal.new(1).should eq(BigDecimal.new(1) + BigDecimal.new(0))
    BigDecimal.new(0).should eq(BigDecimal.new(1) + BigDecimal.new(-1))
    BigDecimal.new(0).should eq(BigDecimal.new(-1) + BigDecimal.new(1))
    BigDecimal.new("0.1").should eq(BigDecimal.new("-1.1") + BigDecimal.new("1.2"))
    BigDecimal.new("0.076543211").should eq(BigDecimal.new("-1.123456789") + BigDecimal.new("1.2"))
    BigDecimal.new("0.13456789").should eq(BigDecimal.new("-1.1") + BigDecimal.new("1.23456789"))

    BigDecimal.new(0).should eq(BigDecimal.new(0) - BigDecimal.new(0))
    BigDecimal.new(-1).should eq(BigDecimal.new(0) - BigDecimal.new(1))
    BigDecimal.new(1).should eq(BigDecimal.new(1) - BigDecimal.new(0))
    BigDecimal.new(2).should eq(BigDecimal.new(1) - BigDecimal.new(-1))
    BigDecimal.new(-2).should eq(BigDecimal.new(-1) - BigDecimal.new(1))
    BigDecimal.new(1).should eq(BigDecimal.new("1.12345") - BigDecimal.new("0.12345"))
    BigDecimal.new("1.0000067").should eq(BigDecimal.new("1.1234567") - BigDecimal.new("0.12345"))
    BigDecimal.new("0.9999933").should eq(BigDecimal.new("1.12345") - BigDecimal.new("0.1234567"))

    BigDecimal.new(0).should eq(BigDecimal.new(0) * BigDecimal.new(0))
    BigDecimal.new(0).should eq(BigDecimal.new(0) * BigDecimal.new(1))
    BigDecimal.new(0).should eq(BigDecimal.new(1) * BigDecimal.new(0))
    BigDecimal.new(-1).should eq(BigDecimal.new(1) * BigDecimal.new(-1))
    BigDecimal.new(-1).should eq(BigDecimal.new(-1) * BigDecimal.new(1))
    BigDecimal.new("1.2621466432").should eq(BigDecimal.new("1.12345") * BigDecimal.new("1.123456"))
    BigDecimal.new("1.2621466432").should eq(BigDecimal.new("1.123456") * BigDecimal.new("1.12345"))

    expect_raises(DivisionByZeroError) do
      BigDecimal.new(0) / BigDecimal.new(0)
    end
    expect_raises(DivisionByZeroError) do
      BigDecimal.new(1) / BigDecimal.new(0)
    end
    expect_raises(DivisionByZeroError) do
      BigDecimal.new(-1) / BigDecimal.new(0)
    end

    expect_raises(DivisionByZeroError) do
      BigDecimal.new(0) // BigDecimal.new(0)
    end
    expect_raises(DivisionByZeroError) do
      BigDecimal.new(1) // BigDecimal.new(0)
    end
    expect_raises(DivisionByZeroError) do
      BigDecimal.new(-1) // BigDecimal.new(0)
    end

    BigDecimal.new(1).should eq(BigDecimal.new(1) / BigDecimal.new(1))
    BigDecimal.new(10).should eq(BigDecimal.new(100, 1) / BigDecimal.new(100000000, 8))
    BigDecimal.new(5.to_big_i, 1_u64).should eq(BigDecimal.new(1) / BigDecimal.new(2))
    BigDecimal.new(-5.to_big_i, 1_u64).should eq(BigDecimal.new(1) / BigDecimal.new(-2))
    BigDecimal.new(-5.to_big_i, 4_u64).should eq(BigDecimal.new(1) / BigDecimal.new(-2000))
    BigDecimal.new(-500.to_big_i, 0).should eq(BigDecimal.new(1000) / BigDecimal.new(-2))
    BigDecimal.new(-500.to_big_i, 0).should eq(BigDecimal.new(-1000) / BigDecimal.new(2))
    BigDecimal.new(500.to_big_i, 0).should eq(BigDecimal.new(-1000) / BigDecimal.new(-2))
    BigDecimal.new(5.to_big_i, 1_u64).should eq(BigDecimal.new(-1) / BigDecimal.new(-2))
    BigDecimal.new(5.to_big_i, 4_u64).should eq(BigDecimal.new(-1) / BigDecimal.new(-2000))
    BigDecimal.new(500.to_big_i, 0).should eq(BigDecimal.new(-1000) / BigDecimal.new(-2))
    BigDecimal.new(0).should eq(BigDecimal.new(0) / BigDecimal.new(1))
    BigDecimal.new("3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333".to_big_i, 100_u64).should eq(BigDecimal.new(1) / BigDecimal.new(3))
    BigDecimal.new(-2000).should eq(BigDecimal.new(-0.02) / (BigDecimal.new(0.00001)))

    BigDecimal.new(0).should eq(BigDecimal.new(1) // BigDecimal.new(2))
    BigDecimal.new(-1).should eq(BigDecimal.new(1) // BigDecimal.new(-2))
    BigDecimal.new(-1).should eq(BigDecimal.new(1) // BigDecimal.new(-2000))
    BigDecimal.new(-500).should eq(BigDecimal.new(1000) // BigDecimal.new(-2))
    BigDecimal.new(-500).should eq(BigDecimal.new(-1000) // BigDecimal.new(2))
    BigDecimal.new(500).should eq(BigDecimal.new(-1000) // BigDecimal.new(-2))
    BigDecimal.new(0).should eq(BigDecimal.new(-1) // BigDecimal.new(-2))
    BigDecimal.new(0).should eq(BigDecimal.new(-1) // BigDecimal.new(-2000))
    BigDecimal.new(500).should eq(BigDecimal.new(-1000) // BigDecimal.new(-2))
    BigDecimal.new(0).should eq(BigDecimal.new(0) // BigDecimal.new(1))
    BigDecimal.new(0).should eq(BigDecimal.new(1) // BigDecimal.new(3))
    BigDecimal.new(-2000).should eq(BigDecimal.new(-0.02) // (BigDecimal.new(0.00001)))

    BigDecimal.new(33333.to_big_i, 5_u64).should eq(BigDecimal.new(1).div(BigDecimal.new(3), 5))
    BigDecimal.new(33.to_big_i, 5_u64).should eq(BigDecimal.new(1).div(BigDecimal.new(3000), 5))

    BigDecimal.new(3333333.to_big_i, 7_u64).should eq(BigDecimal.new(1).div(BigDecimal.new(3), 7))
    BigDecimal.new(3333.to_big_i, 7_u64).should eq(BigDecimal.new(1).div(BigDecimal.new(3000), 7))

    (-BigDecimal.new(3)).should eq(BigDecimal.new(-3))

    (BigDecimal.new(5) % BigDecimal.new(2)).should eq(BigDecimal.new(1))
    (BigDecimal.new(500) % BigDecimal.new(2)).should eq(BigDecimal.new(0))
    (BigDecimal.new(500) % BigDecimal.new(2000)).should eq(BigDecimal.new(500))
  end

  it "handles modulus correctly" do
    (BigDecimal.new(13.0) % BigDecimal.new(4.0)).should eq(BigDecimal.new(1.0))
    (BigDecimal.new(13.0) % BigDecimal.new(-4.0)).should eq(BigDecimal.new(-3.0))
    (BigDecimal.new(-13.0) % BigDecimal.new(4.0)).should eq(BigDecimal.new(3.0))
    (BigDecimal.new(-13.0) % BigDecimal.new(-4.0)).should eq(BigDecimal.new(-1.0))
    (BigDecimal.new(11.5) % BigDecimal.new(4.0)).should eq(BigDecimal.new(3.5))
    (BigDecimal.new(11.5) % BigDecimal.new(-4.0)).should eq(BigDecimal.new(-0.5))
    (BigDecimal.new(-11.5) % BigDecimal.new(4.0)).should eq(BigDecimal.new(0.5))
    (BigDecimal.new(-11.5) % BigDecimal.new(-4.0)).should eq(BigDecimal.new(-3.5))
  end

  it "performs arithmetic with other number types" do
    (1.to_big_d + 2).should eq(BigDecimal.new("3.0"))
    (2 + 1.to_big_d).should eq(BigDecimal.new("3.0"))
    (2.to_big_d - 1).should eq(BigDecimal.new("1.0"))
    (2 - 1.to_big_d).should eq(BigDecimal.new("1.0"))
    (1.to_big_d * 2).should eq(BigDecimal.new("2.0"))
    (1 * 2.to_big_d).should eq(BigDecimal.new("2.0"))
    (3.to_big_d / 2).should eq(BigDecimal.new("1.5"))
    (3 / 2.to_big_d).should eq(BigDecimal.new("1.5"))
  end

  it "exponentiates" do
    result = "12.34".to_big_d ** 5
    result.should be_a(BigDecimal)
    result.to_s.should eq("286138.1721051424")
  end

  it "exponentiates with negative powers" do
    result = "2.0".to_big_d ** -1
    result.should be_a(BigDecimal)
    result.to_s.should eq("0.5")
  end

  it "can be converted from other types" do
    1.to_big_d.should eq(BigDecimal.new(1))
    "1.5".to_big_d.should eq(BigDecimal.new(15, 1))
    "+1.5".to_big_d.should eq(BigDecimal.new(15, 1))
    BigInt.new(15).to_big_d.should eq(BigDecimal.new(15, 0))
    1.5.to_big_d.should eq(BigDecimal.new(15, 1))
    1.5.to_big_f.to_big_d.should eq(BigDecimal.new(15, 1))
    1.5.to_big_r.to_big_d.should eq(BigDecimal.new(15, 1))
  end

  it "can be converted from scientific notation" do
    "10.01e1".to_big_d.should eq(BigDecimal.new("100.1"))
    "10.01e-1".to_big_d.should eq(BigDecimal.new("1.001"))
    "6.033e2".to_big_d.should eq(BigDecimal.new("603.3"))
    "603.3e-2".to_big_d.should eq(BigDecimal.new("6.033"))
    "-0.123e12".to_big_d.should eq(BigDecimal.new("-123000000000"))
    "0.123e12".to_big_d.should eq(BigDecimal.new("123000000000"))
    "0.123e+12".to_big_d.should eq(BigDecimal.new("123000000000"))
    "-0.123e-7".to_big_d.should eq(BigDecimal.new("-0.0000000123"))
    "-0.1e-7".to_big_d.should eq(BigDecimal.new("-0.00000001"))
    "0.1e-7".to_big_d.should eq(BigDecimal.new("0.00000001"))
    "1.0e-8".to_big_d.should eq(BigDecimal.new("0.00000001"))
    "10e-8".to_big_d.should eq(BigDecimal.new("0.0000001"))
    "1.0e+8".to_big_d.should eq(BigDecimal.new("100000000"))
    "10e+8".to_big_d.should eq(BigDecimal.new("1000000000"))
    "10E+8".to_big_d.should eq(BigDecimal.new("1000000000"))
    "10E8".to_big_d.should eq(BigDecimal.new("1000000000"))
  end

  it "is comparable with other types" do
    BigDecimal.new("1.0").should eq BigDecimal.new("1")
    BigDecimal.new("1").should eq BigDecimal.new("1.0")
    1.should_not eq BigDecimal.new("-1.0")
    1.should_not eq BigDecimal.new("0.1")
    BigDecimal.new(1, 10).should eq BigDecimal.new(10, 11)
    BigDecimal.new(10, 11).should eq BigDecimal.new(1, 10)

    (BigDecimal.new(1) > BigDecimal.new(1)).should be_false
    (BigDecimal.new("1.00000000000000000000000000000000000001") > BigDecimal.new(1)).should be_true
    (BigDecimal.new("0.99999999999999999999999999999999999999") > BigDecimal.new(1)).should be_false
    BigDecimal.new("1.00000000000000000000000000000000000000").should eq BigDecimal.new(1)

    (1 < BigDecimal.new(1)).should be_false
    (BigDecimal.new(1) < 1).should be_false
    (2 < BigDecimal.new(1)).should be_false
    (BigDecimal.new(2) < 1).should be_false
    (BigDecimal.new("-1") > BigDecimal.new("1")).should be_false

    (1 > BigDecimal.new(1)).should be_false
    (BigDecimal.new(1) > 1).should be_false
    (2 > BigDecimal.new(1)).should be_true
    (BigDecimal.new(2) > 1).should be_true
    (BigDecimal.new("-1") < BigDecimal.new("1")).should be_true

    (1 >= BigDecimal.new(1)).should be_true
    (2 >= BigDecimal.new(1)).should be_true

    (1 <= BigDecimal.new(1)).should be_true
    (0 <= BigDecimal.new(1)).should be_true

    (BigDecimal.new("6.5") < 6.6).should be_true
    (6.6 > BigDecimal.new("6.5")).should be_true
    (BigDecimal.new("7.5") > 6.6).should be_true
    (6.6 < BigDecimal.new("7.5")).should be_true

    "1.0000000000000002".to_big_d.should be < 1.0.next_float
    (1.0.to_big_d + 0.5.to_big_d ** 52).should eq(1.0.next_float)
    "1.0000000000000003".to_big_d.should be > 1.0.next_float

    1.0.next_float.should be > "1.0000000000000002".to_big_d
    1.0.next_float.should eq(1.0.to_big_d + 0.5.to_big_d ** 52)
    1.0.next_float.should be < "1.0000000000000003".to_big_d

    0.to_big_d.should be < Float64::INFINITY
    (Float64::MAX.to_big_d ** 7).should be < Float64::INFINITY
    0.to_big_d.should be > -Float64::INFINITY
    (Float64::MIN.to_big_d ** 7).should be > -Float64::INFINITY

    Float64::INFINITY.should be > 0.to_big_d
    Float64::INFINITY.should be > (Float64::MAX.to_big_d ** 7)
    (-Float64::INFINITY).should be < 0.to_big_d
    (-Float64::INFINITY).should be < (Float64::MIN.to_big_d ** 7)

    (BigDecimal.new("6.5") > 7).should be_false
    (BigDecimal.new("7.5") > 6).should be_true

    BigDecimal.new("0.5").should eq(BigRational.new(1, 2))
    BigDecimal.new("0.25").should eq(BigDecimal.new("0.25"))

    BigRational.new(1, 2).should eq(BigDecimal.new("0.5"))
    BigRational.new(1, 4).should eq(BigDecimal.new("0.25"))

    (1.to_big_d / 3).should be < BigRational.new(1, 3)
    (-(1.to_big_d / 3)).should be > BigRational.new(-1, 3)
    (-1.to_big_d / 3).should be < BigRational.new(-1, 3)

    BigRational.new(1, 3).should be > 1.to_big_d / 3
    BigRational.new(-1, 3).should be < -(1.to_big_d / 3)
    BigRational.new(-1, 3).should be > -1.to_big_d / 3

    (1.to_big_d / 3 + BigDecimal.new(1, BigDecimal::DEFAULT_PRECISION)).should be > BigRational.new(1, 3)
    (-(1.to_big_d / 3) - BigDecimal.new(1, BigDecimal::DEFAULT_PRECISION)).should be < BigRational.new(-1, 3)

    BigRational.new(1, 3).should be < (1.to_big_d / 3 + BigDecimal.new(1, BigDecimal::DEFAULT_PRECISION))
    BigRational.new(-1, 3).should be > (-(1.to_big_d / 3) - BigDecimal.new(1, BigDecimal::DEFAULT_PRECISION))

    (0.5.to_big_d ** 10000).should eq(0.5.to_big_f ** 10000)
    "5.0123727492064520093e-3011".to_big_d.should be > 0.5.to_big_f ** 10000

    (0.5.to_big_f ** 10000).should eq(0.5.to_big_d ** 10000)
    (0.5.to_big_f ** 10000).should be < "5.0123727492064520093e-3011".to_big_d
  end

  describe "#<=>" do
    it "compares against NaNs" do
      (1.to_big_d <=> Float64::NAN).should be_nil
      (1.to_big_d <=> Float32::NAN).should be_nil
      (Float64::NAN <=> 1.to_big_d).should be_nil
      (Float32::NAN <=> 1.to_big_d).should be_nil

      typeof(1.to_big_d <=> Float64::NAN).should eq(Int32?)
      typeof(1.to_big_d <=> Float32::NAN).should eq(Int32?)
      typeof(Float64::NAN <=> 1.to_big_d).should eq(Int32?)
      typeof(Float32::NAN <=> 1.to_big_d).should eq(Int32?)
    end
  end

  it "keeps precision" do
    one_thousandth = BigDecimal.new("0.001")
    one = BigDecimal.new("1")

    x = BigDecimal.new
    1000.times do
      x += one_thousandth
    end
    one.should eq(x)

    x = BigDecimal.new("2")
    1000.times do
      x -= one_thousandth
    end
    one.should eq(x)
  end

  it "converts to string" do
    assert_prints BigDecimal.new.to_s, "0.0"
    assert_prints BigDecimal.new(0).to_s, "0.0"
    assert_prints BigDecimal.new(1).to_s, "1.0"
    assert_prints BigDecimal.new(-1).to_s, "-1.0"
    assert_prints BigDecimal.new("8.5").to_s, "8.5"
    assert_prints BigDecimal.new("-0.35").to_s, "-0.35"
    assert_prints BigDecimal.new("-.35").to_s, "-0.35"
    assert_prints BigDecimal.new("0.01").to_s, "0.01"
    assert_prints BigDecimal.new("-0.01").to_s, "-0.01"
    assert_prints BigDecimal.new("0.00123").to_s, "0.00123"
    assert_prints BigDecimal.new("-0.00123").to_s, "-0.00123"
    assert_prints BigDecimal.new("1.0").to_s, "1.0"
    assert_prints BigDecimal.new("-1.0").to_s, "-1.0"
    assert_prints BigDecimal.new("1.000").to_s, "1.0"
    assert_prints BigDecimal.new("-1.000").to_s, "-1.0"
    assert_prints BigDecimal.new("1.0001").to_s, "1.0001"
    assert_prints BigDecimal.new("-1.0001").to_s, "-1.0001"

    assert_prints BigDecimal.new(1).div(BigDecimal.new(3), 9).to_s, "0.333333333"
    assert_prints BigDecimal.new(1000).div(BigDecimal.new(3000), 9).to_s, "0.333333333"
    assert_prints BigDecimal.new(1).div(BigDecimal.new(3000), 9).to_s, "0.000333333"

    assert_prints BigDecimal.new("112839719283").div(BigDecimal.new("3123779"), 9).to_s, "36122.824080384"
    assert_prints BigDecimal.new("112839719283").div(BigDecimal.new("3123779"), 14).to_s, "36122.8240803846879"
    assert_prints BigDecimal.new("-0.4098").div(BigDecimal.new("0.2229011193"), 20).to_s, "-1.83848336557007141059"

    assert_prints BigDecimal.new(1, 2).to_s, "0.01"
    assert_prints BigDecimal.new(100, 4).to_s, "0.01"

    assert_prints "12345678901234567".to_big_d.to_s, "1.2345678901234567e+16"
    assert_prints "1234567890123456789".to_big_d.to_s, "1.234567890123456789e+18"

    assert_prints BigDecimal.new(1_000_000_000_000_000_i64, 0).to_s, "1.0e+15"
    assert_prints BigDecimal.new(100_000_000_000_000_i64, 0).to_s, "100000000000000.0"
    assert_prints BigDecimal.new(1, 4).to_s, "0.0001"
    assert_prints BigDecimal.new(1, 5).to_s, "1.0e-5"

    assert_prints "1.23e45".to_big_d.to_s, "1.23e+45"
    assert_prints "1e-234".to_big_d.to_s, "1.0e-234"
  end

  it "converts to other number types" do
    bd1 = BigDecimal.new(123, 5)
    bd2 = BigDecimal.new(-123, 5)
    bd3 = BigDecimal.new(123, 0)
    bd4 = BigDecimal.new(-123, 0)
    bd5 = "-123.000".to_big_d
    bd6 = "-1.1".to_big_d

    bd1.to_i.should eq 0
    bd2.to_i.should eq 0
    bd3.to_i.should eq 123
    bd4.to_i.should eq -123
    bd5.to_i.should eq -123
    bd6.to_i.should eq -1

    bd1.to_u.should eq 0
    expect_raises(OverflowError) { bd2.to_u }
    bd3.to_u.should eq 123
    expect_raises(OverflowError) { bd4.to_u }
    expect_raises(OverflowError) { bd5.to_u }
    expect_raises(OverflowError) { bd6.to_u }

    bd1.to_f.should eq 0.00123
    bd2.to_f.should eq -0.00123
    bd3.to_f.should eq 123.0
    bd4.to_f.should eq -123.0
    bd5.to_f.should eq -123.0
    bd6.to_f.should eq -1.1

    bd1.to_i!.should eq 0
    bd2.to_i!.should eq 0
    bd3.to_i!.should eq 123
    bd4.to_i!.should eq -123
    bd5.to_i!.should eq -123
    bd6.to_i!.should eq -1

    bd1.to_u!.should eq 0
    bd2.to_u!.should eq 0
    bd3.to_u!.should eq 123
    bd4.to_u!.should eq 123
    bd5.to_u!.should eq 123
    bd6.to_u!.should eq 1

    bd1.to_f!.should eq 0.00123
    bd2.to_f!.should eq -0.00123
    bd3.to_f!.should eq 123.0
    bd4.to_f!.should eq -123.0
    bd5.to_f!.should eq -123.0
    bd6.to_f!.should eq -1.1
  end

  it "hashes" do
    bd1 = BigDecimal.new("123.456")
    bd2 = BigDecimal.new("0.12345")
    bd3 = BigDecimal.new("1.23456")
    bd4 = BigDecimal.new("-123456")
    bd5 = BigDecimal.new("0")

    hash = {} of BigDecimal => String
    hash[bd1] = "bd1"
    hash[bd2] = "bd2"
    hash[bd3] = "bd3"
    hash[bd4] = "bd4"
    hash[bd5] = "bd5"

    # regular cases
    hash[BigDecimal.new("123.456")].should eq "bd1"
    hash[BigDecimal.new("0.12345")].should eq "bd2"
    hash[BigDecimal.new("1.23456")].should eq "bd3"
    hash[BigDecimal.new("-123456")].should eq "bd4"
    hash[BigDecimal.new("0")].should eq "bd5"

    # not found
    expect_raises(KeyError) do
      hash[BigDecimal.new("4")]
    end
  end

  it "upkeeps hashing invariant" do
    # a == b => h[a] == h[b]
    bd1 = BigDecimal.new(1, 2)
    bd2 = BigDecimal.new(100, 4)

    bd1.hash.should eq bd2.hash
  end

  it "can normalize quotient" do
    positive_one = BigDecimal.new("1.0")
    negative_one = BigDecimal.new("-1.0")

    positive_ten = BigInt.new(10)
    negative_ten = BigInt.new(-10)

    positive_one.normalize_quotient(positive_one, positive_ten).should eq(positive_ten)
    positive_one.normalize_quotient(positive_one, negative_ten).should eq(negative_ten)

    positive_one.normalize_quotient(negative_one, positive_ten).should eq(negative_ten)
    positive_one.normalize_quotient(negative_one, negative_ten).should eq(negative_ten)

    negative_one.normalize_quotient(positive_one, positive_ten).should eq(negative_ten)
    negative_one.normalize_quotient(positive_one, negative_ten).should eq(negative_ten)

    negative_one.normalize_quotient(negative_one, positive_ten).should eq(positive_ten)
    negative_one.normalize_quotient(negative_one, negative_ten).should eq(negative_ten)
  end

  describe "#ceil" do
    it { 2.0.to_big_d.ceil.should eq(2) }
    it { 2.1.to_big_d.ceil.should eq(3) }
    it { 2.9.to_big_d.ceil.should eq(3) }

    it { 2.01.to_big_d.ceil.should eq(3) }
    it { 2.11.to_big_d.ceil.should eq(3) }
    it { 2.91.to_big_d.ceil.should eq(3) }

    it { -2.01.to_big_d.ceil.should eq(-2) }
    it { -2.91.to_big_d.ceil.should eq(-2) }

    it { "-123.000".to_big_d.ceil.value.should eq(-123) }
    it { "-1.1".to_big_d.ceil.value.should eq(-1) }
  end

  describe "#floor" do
    it { 2.1.to_big_d.floor.should eq(2) }
    it { 2.9.to_big_d.floor.should eq(2) }
    it { -2.9.to_big_d.floor.should eq(-3) }

    it { 2.11.to_big_d.floor.should eq(2) }
    it { 2.91.to_big_d.floor.should eq(2) }
    it { -2.91.to_big_d.floor.should eq(-3) }

    it { "-123.000".to_big_d.floor.value.should eq(-123) }
    it { "-1.1".to_big_d.floor.value.should eq(-2) }
  end

  describe "#trunc" do
    it { 2.1.to_big_d.trunc.should eq(2) }
    it { 2.9.to_big_d.trunc.should eq(2) }
    it { -2.9.to_big_d.trunc.should eq(-2) }

    it { 2.11.to_big_d.trunc.should eq(2) }
    it { 2.91.to_big_d.trunc.should eq(2) }
    it { -2.91.to_big_d.trunc.should eq(-2) }
  end

  describe "#round" do
    describe "rounding modes" do
      it "to_zero" do
        "-1.5".to_big_d.round(:to_zero).should eq "-1".to_big_d
        "-1.0".to_big_d.round(:to_zero).should eq "-1".to_big_d
        "-0.9".to_big_d.round(:to_zero).should eq "0".to_big_d
        "-0.5".to_big_d.round(:to_zero).should eq "0".to_big_d
        "-0.1".to_big_d.round(:to_zero).should eq "0".to_big_d
        "0.0".to_big_d.round(:to_zero).should eq "0".to_big_d
        "0.1".to_big_d.round(:to_zero).should eq "0".to_big_d
        "0.5".to_big_d.round(:to_zero).should eq "0".to_big_d
        "0.9".to_big_d.round(:to_zero).should eq "0".to_big_d
        "1.0".to_big_d.round(:to_zero).should eq "1".to_big_d
        "1.5".to_big_d.round(:to_zero).should eq "1".to_big_d

        "123456789123456789123.0".to_big_d.round(:to_zero).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.1".to_big_d.round(:to_zero).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.5".to_big_d.round(:to_zero).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.9".to_big_d.round(:to_zero).should eq "123456789123456789123.0".to_big_d
        "123456789123456789124.0".to_big_d.round(:to_zero).should eq "123456789123456789124.0".to_big_d
        "-123456789123456789123.0".to_big_d.round(:to_zero).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.1".to_big_d.round(:to_zero).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.5".to_big_d.round(:to_zero).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.9".to_big_d.round(:to_zero).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789124.0".to_big_d.round(:to_zero).should eq "-123456789123456789124.0".to_big_d
      end

      it "to_positive" do
        "-1.5".to_big_d.round(:to_positive).should eq "-1".to_big_d
        "-1.0".to_big_d.round(:to_positive).should eq "-1".to_big_d
        "-0.9".to_big_d.round(:to_positive).should eq "0".to_big_d
        "-0.5".to_big_d.round(:to_positive).should eq "0".to_big_d
        "-0.1".to_big_d.round(:to_positive).should eq "0".to_big_d
        "0.0".to_big_d.round(:to_positive).should eq "0".to_big_d
        "0.1".to_big_d.round(:to_positive).should eq "1".to_big_d
        "0.5".to_big_d.round(:to_positive).should eq "1".to_big_d
        "0.9".to_big_d.round(:to_positive).should eq "1".to_big_d
        "1.0".to_big_d.round(:to_positive).should eq "1".to_big_d
        "1.5".to_big_d.round(:to_positive).should eq "2".to_big_d

        "123456789123456789123.0".to_big_d.round(:to_positive).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.1".to_big_d.round(:to_positive).should eq "123456789123456789124.0".to_big_d
        "123456789123456789123.5".to_big_d.round(:to_positive).should eq "123456789123456789124.0".to_big_d
        "123456789123456789123.9".to_big_d.round(:to_positive).should eq "123456789123456789124.0".to_big_d
        "123456789123456789124.0".to_big_d.round(:to_positive).should eq "123456789123456789124.0".to_big_d
        "-123456789123456789123.0".to_big_d.round(:to_positive).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.1".to_big_d.round(:to_positive).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.5".to_big_d.round(:to_positive).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.9".to_big_d.round(:to_positive).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789124.0".to_big_d.round(:to_positive).should eq "-123456789123456789124.0".to_big_d
      end

      it "to_negative" do
        "-1.5".to_big_d.round(:to_negative).should eq "-2.0".to_big_d
        "-1.0".to_big_d.round(:to_negative).should eq "-1.0".to_big_d
        "-0.9".to_big_d.round(:to_negative).should eq "-1.0".to_big_d
        "-0.5".to_big_d.round(:to_negative).should eq "-1.0".to_big_d
        "-0.1".to_big_d.round(:to_negative).should eq "-1.0".to_big_d
        "0.0".to_big_d.round(:to_negative).should eq "0.0".to_big_d
        "0.1".to_big_d.round(:to_negative).should eq "0.0".to_big_d
        "0.5".to_big_d.round(:to_negative).should eq "0.0".to_big_d
        "0.9".to_big_d.round(:to_negative).should eq "0.0".to_big_d
        "1.0".to_big_d.round(:to_negative).should eq "1.0".to_big_d
        "1.5".to_big_d.round(:to_negative).should eq "1.0".to_big_d

        "123456789123456789123.0".to_big_d.round(:to_negative).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.1".to_big_d.round(:to_negative).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.5".to_big_d.round(:to_negative).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.9".to_big_d.round(:to_negative).should eq "123456789123456789123.0".to_big_d
        "123456789123456789124.0".to_big_d.round(:to_negative).should eq "123456789123456789124.0".to_big_d
        "-123456789123456789123.0".to_big_d.round(:to_negative).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.1".to_big_d.round(:to_negative).should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789123.5".to_big_d.round(:to_negative).should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789123.9".to_big_d.round(:to_negative).should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789124.0".to_big_d.round(:to_negative).should eq "-123456789123456789124.0".to_big_d
      end

      it "ties_even" do
        "-2.5".to_big_d.round(:ties_even).should eq "-2.0".to_big_d
        "-1.5".to_big_d.round(:ties_even).should eq "-2.0".to_big_d
        "-1.0".to_big_d.round(:ties_even).should eq "-1.0".to_big_d
        "-0.9".to_big_d.round(:ties_even).should eq "-1.0".to_big_d
        "-0.5".to_big_d.round(:ties_even).should eq "0.0".to_big_d
        "-0.1".to_big_d.round(:ties_even).should eq "0.0".to_big_d
        "0.0".to_big_d.round(:ties_even).should eq "0.0".to_big_d
        "0.1".to_big_d.round(:ties_even).should eq "0.0".to_big_d
        "0.5".to_big_d.round(:ties_even).should eq "0.0".to_big_d
        "0.9".to_big_d.round(:ties_even).should eq "1.0".to_big_d
        "1.0".to_big_d.round(:ties_even).should eq "1.0".to_big_d
        "1.5".to_big_d.round(:ties_even).should eq "2.0".to_big_d
        "2.5".to_big_d.round(:ties_even).should eq "2.0".to_big_d

        "123456789123456789123.0".to_big_d.round(:ties_even).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.1".to_big_d.round(:ties_even).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.5".to_big_d.round(:ties_even).should eq "123456789123456789124.0".to_big_d
        "123456789123456789123.9".to_big_d.round(:ties_even).should eq "123456789123456789124.0".to_big_d
        "123456789123456789124.0".to_big_d.round(:ties_even).should eq "123456789123456789124.0".to_big_d
        "123456789123456789124.5".to_big_d.round(:ties_even).should eq "123456789123456789124.0".to_big_d
        "-123456789123456789123.0".to_big_d.round(:ties_even).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.1".to_big_d.round(:ties_even).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.5".to_big_d.round(:ties_even).should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789123.9".to_big_d.round(:ties_even).should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789124.0".to_big_d.round(:ties_even).should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789124.5".to_big_d.round(:ties_even).should eq "-123456789123456789124.0".to_big_d
      end

      it "ties_away" do
        "-2.5".to_big_d.round(:ties_away).should eq "-3.0".to_big_d
        "-1.5".to_big_d.round(:ties_away).should eq "-2.0".to_big_d
        "-1.0".to_big_d.round(:ties_away).should eq "-1.0".to_big_d
        "-0.9".to_big_d.round(:ties_away).should eq "-1.0".to_big_d
        "-0.5".to_big_d.round(:ties_away).should eq "-1.0".to_big_d
        "-0.1".to_big_d.round(:ties_away).should eq "0.0".to_big_d
        "0.0".to_big_d.round(:ties_away).should eq "0.0".to_big_d
        "0.1".to_big_d.round(:ties_away).should eq "0.0".to_big_d
        "0.5".to_big_d.round(:ties_away).should eq "1.0".to_big_d
        "0.9".to_big_d.round(:ties_away).should eq "1.0".to_big_d
        "1.0".to_big_d.round(:ties_away).should eq "1.0".to_big_d
        "1.5".to_big_d.round(:ties_away).should eq "2.0".to_big_d
        "2.5".to_big_d.round(:ties_away).should eq "3.0".to_big_d

        "123456789123456789123.0".to_big_d.round(:ties_away).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.1".to_big_d.round(:ties_away).should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.5".to_big_d.round(:ties_away).should eq "123456789123456789124.0".to_big_d
        "123456789123456789123.9".to_big_d.round(:ties_away).should eq "123456789123456789124.0".to_big_d
        "123456789123456789124.0".to_big_d.round(:ties_away).should eq "123456789123456789124.0".to_big_d
        "123456789123456789124.5".to_big_d.round(:ties_away).should eq "123456789123456789125.0".to_big_d
        "-123456789123456789123.0".to_big_d.round(:ties_away).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.1".to_big_d.round(:ties_away).should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.5".to_big_d.round(:ties_away).should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789123.9".to_big_d.round(:ties_away).should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789124.0".to_big_d.round(:ties_away).should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789124.5".to_big_d.round(:ties_away).should eq "-123456789123456789125.0".to_big_d
      end

      it "default (=ties_even)" do
        "-2.5".to_big_d.round.should eq "-2.0".to_big_d
        "-1.5".to_big_d.round.should eq "-2.0".to_big_d
        "-1.0".to_big_d.round.should eq "-1.0".to_big_d
        "-0.9".to_big_d.round.should eq "-1.0".to_big_d
        "-0.5".to_big_d.round.should eq "0.0".to_big_d
        "-0.1".to_big_d.round.should eq "0.0".to_big_d
        "0.0".to_big_d.round.should eq "0.0".to_big_d
        "0.1".to_big_d.round.should eq "0.0".to_big_d
        "0.5".to_big_d.round.should eq "0.0".to_big_d
        "0.9".to_big_d.round.should eq "1.0".to_big_d
        "1.0".to_big_d.round.should eq "1.0".to_big_d
        "1.5".to_big_d.round.should eq "2.0".to_big_d
        "2.5".to_big_d.round.should eq "2.0".to_big_d

        "123456789123456789123.0".to_big_d.round.should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.1".to_big_d.round.should eq "123456789123456789123.0".to_big_d
        "123456789123456789123.5".to_big_d.round.should eq "123456789123456789124.0".to_big_d
        "123456789123456789123.9".to_big_d.round.should eq "123456789123456789124.0".to_big_d
        "123456789123456789124.0".to_big_d.round.should eq "123456789123456789124.0".to_big_d
        "123456789123456789124.5".to_big_d.round.should eq "123456789123456789124.0".to_big_d
        "-123456789123456789123.0".to_big_d.round.should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.1".to_big_d.round.should eq "-123456789123456789123.0".to_big_d
        "-123456789123456789123.5".to_big_d.round.should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789123.9".to_big_d.round.should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789124.0".to_big_d.round.should eq "-123456789123456789124.0".to_big_d
        "-123456789123456789124.5".to_big_d.round.should eq "-123456789123456789124.0".to_big_d
      end
    end

    describe "with digits" do
      it "to_zero" do
        "12.345".to_big_d.round(-1, mode: :to_zero).should eq "10".to_big_d
        "12.345".to_big_d.round(0, mode: :to_zero).should eq "12".to_big_d
        "12.345".to_big_d.round(1, mode: :to_zero).should eq "12.3".to_big_d
        "12.345".to_big_d.round(2, mode: :to_zero).should eq "12.34".to_big_d
        "-12.345".to_big_d.round(-1, mode: :to_zero).should eq "-10".to_big_d
        "-12.345".to_big_d.round(0, mode: :to_zero).should eq "-12".to_big_d
        "-12.345".to_big_d.round(1, mode: :to_zero).should eq "-12.3".to_big_d
        "-12.345".to_big_d.round(2, mode: :to_zero).should eq "-12.34".to_big_d

        # 1 + 3.0000e-200 -> 1 + 3.0e-200 (ditto for others)
        (1.to_big_d + BigDecimal.new(30000, 204)).round(200, mode: :to_zero).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(30001, 204)).round(200, mode: :to_zero).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(39999, 204)).round(200, mode: :to_zero).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(40000, 204)).round(200, mode: :to_zero).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(40001, 204)).round(200, mode: :to_zero).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(49999, 204)).round(200, mode: :to_zero).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(50000, 204)).round(200, mode: :to_zero).should eq(1.to_big_d + BigDecimal.new(5, 200))

        (-1.to_big_d - BigDecimal.new(30000, 204)).round(200, mode: :to_zero).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(30001, 204)).round(200, mode: :to_zero).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(39999, 204)).round(200, mode: :to_zero).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(40000, 204)).round(200, mode: :to_zero).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(40001, 204)).round(200, mode: :to_zero).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(49999, 204)).round(200, mode: :to_zero).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(50000, 204)).round(200, mode: :to_zero).should eq(-1.to_big_d - BigDecimal.new(5, 200))
      end

      it "to_positive" do
        "12.345".to_big_d.round(-1, mode: :to_positive).should eq "20".to_big_d
        "12.345".to_big_d.round(0, mode: :to_positive).should eq "13".to_big_d
        "12.345".to_big_d.round(1, mode: :to_positive).should eq "12.4".to_big_d
        "12.345".to_big_d.round(2, mode: :to_positive).should eq "12.35".to_big_d
        "-12.345".to_big_d.round(-1, mode: :to_positive).should eq "-10".to_big_d
        "-12.345".to_big_d.round(0, mode: :to_positive).should eq "-12".to_big_d
        "-12.345".to_big_d.round(1, mode: :to_positive).should eq "-12.3".to_big_d
        "-12.345".to_big_d.round(2, mode: :to_positive).should eq "-12.34".to_big_d

        # 1 + 3.0000e-200 -> 1 + 3.0e-200 (ditto for others)
        (1.to_big_d + BigDecimal.new(30000, 204)).round(200, mode: :to_positive).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(30001, 204)).round(200, mode: :to_positive).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(39999, 204)).round(200, mode: :to_positive).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(40000, 204)).round(200, mode: :to_positive).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(40001, 204)).round(200, mode: :to_positive).should eq(1.to_big_d + BigDecimal.new(5, 200))
        (1.to_big_d + BigDecimal.new(49999, 204)).round(200, mode: :to_positive).should eq(1.to_big_d + BigDecimal.new(5, 200))
        (1.to_big_d + BigDecimal.new(50000, 204)).round(200, mode: :to_positive).should eq(1.to_big_d + BigDecimal.new(5, 200))

        (-1.to_big_d - BigDecimal.new(30000, 204)).round(200, mode: :to_positive).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(30001, 204)).round(200, mode: :to_positive).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(39999, 204)).round(200, mode: :to_positive).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(40000, 204)).round(200, mode: :to_positive).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(40001, 204)).round(200, mode: :to_positive).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(49999, 204)).round(200, mode: :to_positive).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(50000, 204)).round(200, mode: :to_positive).should eq(-1.to_big_d - BigDecimal.new(5, 200))
      end

      it "to_negative" do
        "12.345".to_big_d.round(-1, mode: :to_negative).should eq "10".to_big_d
        "12.345".to_big_d.round(0, mode: :to_negative).should eq "12".to_big_d
        "12.345".to_big_d.round(1, mode: :to_negative).should eq "12.3".to_big_d
        "12.345".to_big_d.round(2, mode: :to_negative).should eq "12.34".to_big_d
        "-12.345".to_big_d.round(-1, mode: :to_negative).should eq "-20".to_big_d
        "-12.345".to_big_d.round(0, mode: :to_negative).should eq "-13".to_big_d
        "-12.345".to_big_d.round(1, mode: :to_negative).should eq "-12.4".to_big_d
        "-12.345".to_big_d.round(2, mode: :to_negative).should eq "-12.35".to_big_d

        # 1 + 3.0000e-200 -> 1 + 3.0e-200 (ditto for others)
        (1.to_big_d + BigDecimal.new(30000, 204)).round(200, mode: :to_negative).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(30001, 204)).round(200, mode: :to_negative).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(39999, 204)).round(200, mode: :to_negative).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(40000, 204)).round(200, mode: :to_negative).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(40001, 204)).round(200, mode: :to_negative).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(49999, 204)).round(200, mode: :to_negative).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(50000, 204)).round(200, mode: :to_negative).should eq(1.to_big_d + BigDecimal.new(5, 200))

        (-1.to_big_d - BigDecimal.new(30000, 204)).round(200, mode: :to_negative).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(30001, 204)).round(200, mode: :to_negative).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(39999, 204)).round(200, mode: :to_negative).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(40000, 204)).round(200, mode: :to_negative).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(40001, 204)).round(200, mode: :to_negative).should eq(-1.to_big_d - BigDecimal.new(5, 200))
        (-1.to_big_d - BigDecimal.new(49999, 204)).round(200, mode: :to_negative).should eq(-1.to_big_d - BigDecimal.new(5, 200))
        (-1.to_big_d - BigDecimal.new(50000, 204)).round(200, mode: :to_negative).should eq(-1.to_big_d - BigDecimal.new(5, 200))
      end

      it "ties_away" do
        "13.825".to_big_d.round(-1, mode: :ties_away).should eq "10".to_big_d
        "13.825".to_big_d.round(0, mode: :ties_away).should eq "14".to_big_d
        "13.825".to_big_d.round(1, mode: :ties_away).should eq "13.8".to_big_d
        "13.825".to_big_d.round(2, mode: :ties_away).should eq "13.83".to_big_d
        "-13.825".to_big_d.round(-1, mode: :ties_away).should eq "-10".to_big_d
        "-13.825".to_big_d.round(0, mode: :ties_away).should eq "-14".to_big_d
        "-13.825".to_big_d.round(1, mode: :ties_away).should eq "-13.8".to_big_d
        "-13.825".to_big_d.round(2, mode: :ties_away).should eq "-13.83".to_big_d

        # 1 + 3.0000e-200 -> 1 + 3.0e-200 (ditto for others)
        (1.to_big_d + BigDecimal.new(30000, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(30001, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(34999, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(35000, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(35001, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(39999, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(40000, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(40001, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(44999, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(45000, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(5, 200))
        (1.to_big_d + BigDecimal.new(45001, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(5, 200))
        (1.to_big_d + BigDecimal.new(50000, 204)).round(200, mode: :ties_away).should eq(1.to_big_d + BigDecimal.new(5, 200))

        (-1.to_big_d - BigDecimal.new(30000, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(30001, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(34999, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(35000, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(35001, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(39999, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(40000, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(40001, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(44999, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(45000, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(5, 200))
        (-1.to_big_d - BigDecimal.new(45001, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(5, 200))
        (-1.to_big_d - BigDecimal.new(50000, 204)).round(200, mode: :ties_away).should eq(-1.to_big_d - BigDecimal.new(5, 200))
      end

      it "ties_even" do
        "15.255".to_big_d.round(-1, mode: :ties_even).should eq "20".to_big_d
        "15.255".to_big_d.round(0, mode: :ties_even).should eq "15".to_big_d
        "15.255".to_big_d.round(1, mode: :ties_even).should eq "15.3".to_big_d
        "15.255".to_big_d.round(2, mode: :ties_even).should eq "15.26".to_big_d
        "-15.255".to_big_d.round(-1, mode: :ties_even).should eq "-20".to_big_d
        "-15.255".to_big_d.round(0, mode: :ties_even).should eq "-15".to_big_d
        "-15.255".to_big_d.round(1, mode: :ties_even).should eq "-15.3".to_big_d
        "-15.255".to_big_d.round(2, mode: :ties_even).should eq "-15.26".to_big_d

        # 1 + 3.0000e-200 -> 1 + 3.0e-200 (ditto for others)
        (1.to_big_d + BigDecimal.new(30000, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(30001, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(34999, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(3, 200))
        (1.to_big_d + BigDecimal.new(35000, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(35001, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(39999, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(40000, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(40001, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(44999, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(45000, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(4, 200))
        (1.to_big_d + BigDecimal.new(45001, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(5, 200))
        (1.to_big_d + BigDecimal.new(50000, 204)).round(200, mode: :ties_even).should eq(1.to_big_d + BigDecimal.new(5, 200))

        (-1.to_big_d - BigDecimal.new(30000, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(30001, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(34999, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(3, 200))
        (-1.to_big_d - BigDecimal.new(35000, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(35001, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(39999, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(40000, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(40001, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(44999, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(45000, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(4, 200))
        (-1.to_big_d - BigDecimal.new(45001, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(5, 200))
        (-1.to_big_d - BigDecimal.new(50000, 204)).round(200, mode: :ties_even).should eq(-1.to_big_d - BigDecimal.new(5, 200))
      end
    end
  end

  describe "#inspect" do
    it { "123".to_big_d.inspect.should eq("123.0") }
  end
end
