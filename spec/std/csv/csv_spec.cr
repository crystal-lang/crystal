require "spec"
require "csv"

private def new_csv(headers = false, strip = false)
  CSV.new %(one, two\n1, 2\n3, 4\n5), headers: headers, strip: strip
end

describe CSV do
  it "gets headers" do
    csv = new_csv headers: true
    csv.headers.should eq(%w(one two))
  end

  it "works without headers" do
    csv = CSV.new("", headers: true)
    csv.headers.empty?.should be_true
  end

  it "raises if trying to access before first row" do
    csv = new_csv headers: true
    expect_raises(CSV::Error, "Before first row") do
      csv["one"]
    end
  end

  it "gets row values with string" do
    csv = new_csv headers: true
    csv.next.should be_true
    csv["one"].should eq("1")
    csv["two"].should eq(" 2")

    expect_raises(KeyError) { csv["three"] }

    csv["one"]?.should eq("1")
    csv["three"]?.should be_nil

    csv.next.should be_true
    csv["one"].should eq("3")

    csv.next.should be_true
    csv["one"].should eq("5")
    csv["two"].should eq("")

    csv.next.should be_false

    expect_raises(CSV::Error, "After last row") do
      csv["one"]
    end
  end

  it "gets row values with integer" do
    csv = new_csv headers: true
    csv.next.should be_true
    csv[0].should eq("1")
    csv[1].should eq(" 2")

    expect_raises(IndexError) do
      csv[2]
    end

    csv[-1].should eq(" 2")
    csv[-2].should eq("1")

    csv.next
    csv.next

    csv[0].should eq("5")
    csv[1].should eq("")
    csv[-2].should eq("5")
    csv[-1].should eq("")
  end

  it "gets row values with regex" do
    csv = new_csv headers: true
    csv.next.should be_true

    csv[/on/].should eq("1")
    csv[/tw/].should eq(" 2")

    expect_raises(KeyError) do
      csv[/foo/]
    end
  end

  it "gets current row" do
    csv = new_csv headers: true
    csv.next.should be_true

    row = csv.row
    row["one"].should eq("1")
    row[1].should eq(" 2")
    row[/on/].should eq("1")
    row.size.should eq(2)

    row.to_a.should eq(["1", " 2"])
    row.to_h.should eq({"one" => "1", "two" => " 2"})
  end

  it "strips" do
    csv = new_csv headers: true, strip: true
    csv.next.should be_true

    csv["one"].should eq("1")
    csv["two"].should eq("2")

    csv.row.to_a.should eq(%w(1 2))
    csv.row.to_h.should eq({"one" => "1", "two" => "2"})
  end

  it "works without headers" do
    csv = new_csv headers: false
    csv.next.should be_true
    csv[0].should eq("one")
  end

  it "can do each" do
    csv = new_csv headers: true
    csv.each do
      csv["one"].should eq("1")
      break
    end.should be_nil
  end

  it "can do new with block" do
    CSV.new(%(one, two\n1, 2\n3, 4\n5), headers: true, strip: true) do |csv|
      csv["one"].should eq("1")
      csv["two"].should eq("2")
      break
    end
  end

  it "returns a Tuple(String, String) for current row with indices" do
    CSV.new("John,20\nPeter,30") do |csv|
      csv.values_at(0, -1).should eq({"John", "20"})
      break
    end
  end

  it "returns a Tuple(String, String) for current row with headers" do
    CSV.new("Name,Age\nJohn,20\nPeter,30", headers: true) do |csv|
      csv.values_at("Name", "Age").should eq({"John", "20"})
      break
    end
  end

  it "returns a Tuple(String, String) for this row with indices" do
    CSV.new("John,20\nPeter,30") do |csv|
      csv.row.values_at(0, -1).should eq({"John", "20"})
      break
    end
  end

  it "returns a Tuple(String, String) for this row with headers" do
    CSV.new("Name,Age\nJohn,20\nPeter,30", headers: true) do |csv|
      csv.row.values_at("Name", "Age").should eq({"John", "20"})
      break
    end
  end
end
