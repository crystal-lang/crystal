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
      stmt.params[0].should eq("a")
      stmt.params[1].should eq(1)
      stmt.params[2].should eq(nil)
    end
  end

  it "should initialize positional params in exec" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.exec "a", 1, nil
      stmt.params[0].should eq("a")
      stmt.params[1].should eq(1)
      stmt.params[2].should eq(nil)
    end
  end

  it "should initialize positional params in scalar" do
    with_dummy do |db|
      stmt = db.prepare("the query")
      stmt.scalar "a", 1, nil
      stmt.params[0].should eq("a")
      stmt.params[1].should eq(1)
      stmt.params[2].should eq(nil)
    end
  end

  it "query with block should not close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.query
      stmt.closed?.should be_false
    end
  end

  it "query with block should not close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.query do |rs|
      end
      stmt.closed?.should be_false
    end
  end

  it "query should not close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.query do |rs|
      end
      stmt.closed?.should be_false
    end
  end

  it "scalar should not close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.scalar
      stmt.closed?.should be_false
    end
  end

  it "exec should not close statement" do
    with_dummy do |db|
      stmt = db.prepare "3,4 1,2"
      stmt.exec
      stmt.closed?.should be_false
    end
  end

  it "connection should cache statements by query" do
    with_dummy do |db|
      rs = db.query "1, ?", 2
      stmt = rs.statement
      rs.close

      rs = db.query "1, ?", 4
      rs.statement.should be(stmt)
    end
  end
end
