require "spec"
require "db"
require "./dummy_driver"

describe DB::Statement do
  it "should prepare statements" do
    with_dummy do |db|
      db.prepare("the query").should be_a(DB::Statement)
    end
  end

  it "should initialize positional params in query" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.query "a", 1, nil
      stmt.params[1].should eq("a")
      stmt.params[2].should eq(1)
      stmt.params[3].should eq(nil)
    end
  end

  it "should initialize symbol named params in query" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.query({a: "a", b: 1, c: nil})
      stmt.params[":a"].should eq("a")
      stmt.params[":b"].should eq(1)
      stmt.params[":c"].should eq(nil)
    end
  end

  it "should initialize string named params in query" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.query({"a": "a", "b": 1, "c": nil})
      stmt.params[":a"].should eq("a")
      stmt.params[":b"].should eq(1)
      stmt.params[":c"].should eq(nil)
    end
  end

  it "should initialize positional params in exec" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.exec "a", 1, nil
      stmt.params[1].should eq("a")
      stmt.params[2].should eq(1)
      stmt.params[3].should eq(nil)
    end
  end

  it "should initialize symbol named params in exec" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.exec({a: "a", b: 1, c: nil})
      stmt.params[":a"].should eq("a")
      stmt.params[":b"].should eq(1)
      stmt.params[":c"].should eq(nil)
    end
  end

  it "should initialize string named params in exec" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.exec({"a": "a", "b": 1, "c": nil})
      stmt.params[":a"].should eq("a")
      stmt.params[":b"].should eq(1)
      stmt.params[":c"].should eq(nil)
    end
  end

  it "should initialize positional params in scalar" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.scalar String, "a", 1, nil
      stmt.params[1].should eq("a")
      stmt.params[2].should eq(1)
      stmt.params[3].should eq(nil)
    end
  end

  it "should initialize symbol named params in scalar" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.scalar(String, {a: "a", b: 1, c: nil})
      stmt.params[":a"].should eq("a")
      stmt.params[":b"].should eq(1)
      stmt.params[":c"].should eq(nil)
    end
  end

  it "should initialize string named params in scalar" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.scalar(String, {"a": "a", "b": 1, "c": nil})
      stmt.params[":a"].should eq("a")
      stmt.params[":b"].should eq(1)
      stmt.params[":c"].should eq(nil)
    end
  end

  it "should initialize positional params in scalar?" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.scalar? String, "a", 1, nil
      stmt.params[1].should eq("a")
      stmt.params[2].should eq(1)
      stmt.params[3].should eq(nil)
    end
  end

  it "should initialize symbol named params in scalar?" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.scalar?(String, {a: "a", b: 1, c: nil})
      stmt.params[":a"].should eq("a")
      stmt.params[":b"].should eq(1)
      stmt.params[":c"].should eq(nil)
    end
  end

  it "should initialize string named params in scalar?" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.scalar?(String, {"a": "a", "b": 1, "c": nil})
      stmt.params[":a"].should eq("a")
      stmt.params[":b"].should eq(1)
      stmt.params[":c"].should eq(nil)
    end
  end

  it "query with block should not close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.query
      stmt.closed?.should be_false
    end
  end

  it "query with block should close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.query do |rs|
      end
      stmt.closed?.should be_true
    end
  end

  it "query should close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.query do |rs|
      end
      stmt.closed?.should be_true
    end
  end

  it "scalar should close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.scalar
      stmt.closed?.should be_true
    end
  end

  it "scalar should close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.scalar?
      stmt.closed?.should be_true
    end
  end

  it "exec should close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.exec
      stmt.closed?.should be_true
    end
  end
end
