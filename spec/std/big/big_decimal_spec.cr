require "spec"
require "big_decimal"

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

    expect_raises(DivisionByZero) do
      BigDecimal.new(0) / BigDecimal.new(0)
    end
    expect_raises(DivisionByZero) do
      BigDecimal.new(1) / BigDecimal.new(0)
    end
    expect_raises(DivisionByZero) do
      BigDecimal.new(-1) / BigDecimal.new(0)
    end
    BigDecimal.new(1).should eq(BigDecimal.new(1) / BigDecimal.new(1))
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

    BigDecimal.new(33333.to_big_i, 5_u64).should eq(BigDecimal.new(1).div(BigDecimal.new(3), 5))
    BigDecimal.new(33.to_big_i, 5_u64).should eq(BigDecimal.new(1).div(BigDecimal.new(3000), 5))

    BigDecimal.new(3333333.to_big_i, 7_u64).should eq(BigDecimal.new(1).div(BigDecimal.new(3), 7))
    BigDecimal.new(3333.to_big_i, 7_u64).should eq(BigDecimal.new(1).div(BigDecimal.new(3000), 7))
  end

  it "can be converted from other types" do
    1.to_big_d.should eq (BigDecimal.new(1))
    "1.5".to_big_d.should eq (BigDecimal.new("1.5"))
    BigInt.new(15).to_big_d.should eq (BigDecimal.new("15"))
  end

  it "is comparable with other types" do
    BigDecimal.new("1.0").should eq BigDecimal.new("1")
    BigDecimal.new("1").should eq BigDecimal.new("1.0")
    BigDecimal.new(1, 10).should eq BigDecimal.new(10, 11)
    BigDecimal.new(10, 11).should eq BigDecimal.new(1, 10)

    (BigDecimal.new(1) > BigDecimal.new(1)).should be_false
    (BigDecimal.new("1.00000000000000000000000000000000000001") > BigDecimal.new(1)).should be_true
    (BigDecimal.new("0.99999999999999999999999999999999999999") > BigDecimal.new(1)).should be_false
    BigDecimal.new("1.00000000000000000000000000000000000000").should eq BigDecimal.new(1)

    (1 < BigDecimal.new(1)).should be_false

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
    BigDecimal.new.to_s.should eq "0"
    BigDecimal.new(0).to_s.should eq "0"
    BigDecimal.new(1).to_s.should eq "1"
    BigDecimal.new(-1).to_s.should eq "-1"
    BigDecimal.new("0.01").to_s.should eq "0.01"
    BigDecimal.new("1.0").to_s.should eq "1.0"
    BigDecimal.new("-1.0").to_s.should eq "-1.0"
    BigDecimal.new("1.000").to_s.should eq "1.000"
    BigDecimal.new("-1.000").to_s.should eq "-1.000"
    BigDecimal.new("1.0001").to_s.should eq "1.0001"
    BigDecimal.new("-1.0001").to_s.should eq "-1.0001"

    (BigDecimal.new(1).div(BigDecimal.new(3), 9)).to_s.should eq "0.333333333"
    (BigDecimal.new(1000).div(BigDecimal.new(3000), 9)).to_s.should eq "0.333333333"
    (BigDecimal.new(1).div(BigDecimal.new(3000), 9)).to_s.should eq "0.000333333"

    (BigDecimal.new("112839719283").div(BigDecimal.new("3123779"), 9)).to_s.should eq "36122.824080384"
    (BigDecimal.new("112839719283").div(BigDecimal.new("3123779"), 14)).to_s.should eq "36122.82408038468790"
  end
end
