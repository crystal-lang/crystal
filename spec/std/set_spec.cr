require "spec"
require "set"

describe "Set" do
  describe "an empty set" do
    it "is empty" do
      Set(Nil).new.empty?.should be_true
    end

    it "has size 0" do
      Set(Nil).new.size.should eq(0)
    end
  end

  describe "new" do
    it "creates new set with enumerable without block" do
      set_from_array = Set.new([2, 4, 6, 4])
      set_from_array.size.should eq(3)
      set_from_array.to_a.sort.should eq([2, 4, 6])

      set_from_tulpe = Set.new({1, "hello", 'x'})
      set_from_tulpe.size.should eq(3)
      set_from_tulpe.to_a.includes?(1).should be_true
      set_from_tulpe.to_a.includes?("hello").should be_true
      set_from_tulpe.to_a.includes?('x').should be_true
    end
  end

  describe "add" do
    it "adds and includes" do
      set = Set(Int32).new
      set.add 1
      set.includes?(1).should be_true
      set.size.should eq(1)
    end

    it "returns self" do
      set = Set(Int32).new
      set.add(1).should eq(set)
    end
  end

  describe "delete" do
    it "deletes an object" do
      set = Set{1, 2, 3}
      set.delete 2
      set.size.should eq(2)
      set.includes?(1).should be_true
      set.includes?(3).should be_true
    end

    it "returns self" do
      set = Set{1, 2, 3}
      set.delete(2).should eq(set)
    end
  end

  describe "dup" do
    it "creates a dup" do
      set1 = Set{[1, 2]}
      set2 = set1.dup

      set1.should eq(set2)
      set1.should_not be(set2)

      set1.to_a.first.should be(set2.to_a.first)

      set1 << [3]
      set2 << [4]

      set2.should eq(Set{[1, 2], [4]})
    end
  end

  describe "clone" do
    it "creates a clone" do
      set1 = Set{[1, 2]}
      set2 = set1.clone

      set1.should eq(set2)
      set1.should_not be(set2)

      set1.to_a.first.should_not be(set2.to_a.first)

      set1 << [3]
      set2 << [4]

      set2.should eq(Set{[1, 2], [4]})
    end
  end

  describe "==" do
    it "compares two sets" do
      set1 = Set{1, 2, 3}
      set2 = Set{1, 2, 3}
      set3 = Set{1, 2, 3, 4}

      set1.should eq(set1)
      set1.should eq(set2)
      set1.should_not eq(set3)
    end
  end

  describe "concat" do
    it "adds all the other elements" do
      set = Set{1, 4, 8}
      set.concat [1, 9, 10]
      set.should eq(Set{1, 4, 8, 9, 10})
    end

    it "returns self" do
      set = Set{1, 4, 8}
      set.concat([1, 9, 10]).should eq(Set{1, 4, 8, 9, 10})
    end
  end

  it "does &" do
    set1 = Set{1, 2, 3}
    set2 = Set{4, 2, 5, 3}
    set3 = set1 & set2
    set3.should eq(Set{2, 3})
  end

  it "does |" do
    set1 = Set{1, 2, 3}
    set2 = Set{4, 2, 5, "3"}
    set3 = set1 | set2
    set3.should eq(Set{1, 2, 3, 4, 5, "3"})
  end

  it "does -" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = Set{2, 4, 6}
    set3 = set1 - set2
    set3.should eq(Set{1, 3, 5})
  end

  it "does -" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = Set{2, 4, 'a'}
    set3 = set1 - set2
    set3.should eq(Set{1, 3, 5})
  end

  it "does -" do
    set1 = Set{1, 2, 3, 4, 'b'}
    set2 = Set{2, 4, 5}
    set3 = set1 - set2
    set3.should eq(Set{1, 3, 'b'})
  end

  it "does -" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = [2, 4, 6]
    set3 = set1 - set2
    set3.should eq(Set{1, 3, 5})
  end

  it "does -" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = [2, 4, 'a']
    set3 = set1 - set2
    set3.should eq(Set{1, 3, 5})
  end

  it "does -" do
    set1 = Set{1, 2, 3, 4, 'b'}
    set2 = [2, 4, 5]
    set3 = set1 - set2
    set3.should eq(Set{1, 3, 'b'})
  end

  it "does ^" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = Set{2, 4, 6}
    set3 = set1 ^ set2
    set3.should eq(Set{1, 3, 5, 6})
  end

  it "does ^" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = Set{2, 4, 'a'}
    set3 = set1 ^ set2
    set3.should eq(Set{1, 3, 5, 'a'})
  end

  it "does ^" do
    set1 = Set{1, 2, 3, 4, 'b'}
    set2 = Set{2, 4, 5}
    set3 = set1 ^ set2
    set3.should eq(Set{1, 3, 5, 'b'})
  end

  it "does ^" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = [2, 4, 6]
    set3 = set1 ^ set2
    set3.should eq(Set{1, 3, 5, 6})
  end

  it "does ^" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = [2, 4, 'a']
    set3 = set1 ^ set2
    set3.should eq(Set{1, 3, 5, 'a'})
  end

  it "does ^" do
    set1 = Set{1, 2, 3, 4, 'b'}
    set2 = [2, 4, 5]
    set3 = set1 ^ set2
    set3.should eq(Set{1, 3, 5, 'b'})
  end

  it "does subtract" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = Set{2, 4, 6}
    set1.subtract set2
    set1.should eq(Set{1, 3, 5})
  end

  it "does subtract" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = Set{2, 4, 'a'}
    set1.subtract set2
    set1.should eq(Set{1, 3, 5})
  end

  it "does subtract" do
    set1 = Set{1, 2, 3, 4, 'b'}
    set2 = Set{2, 4, 5}
    set1.subtract set2
    set1.should eq(Set{1, 3, 'b'})
  end

  it "does subtract" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = [2, 4, 6]
    set1.subtract set2
    set1.should eq(Set{1, 3, 5})
  end

  it "does subtract" do
    set1 = Set{1, 2, 3, 4, 5}
    set2 = [2, 4, 'a']
    set1.subtract set2
    set1.should eq(Set{1, 3, 5})
  end

  it "does subtract" do
    set1 = Set{1, 2, 3, 4, 'b'}
    set2 = [2, 4, 5]
    set1.subtract set2
    set1.should eq(Set{1, 3, 'b'})
  end

  it "does to_a" do
    Set{1, 2, 3}.to_a.should eq([1, 2, 3])
  end

  it "does to_s" do
    Set{1, 2, 3}.to_s.should eq("Set{1, 2, 3}")
    Set{"foo"}.to_s.should eq(%(Set{"foo"}))
  end

  it "does clear" do
    x = Set{1, 2, 3}
    x.to_a.should eq([1, 2, 3])
    x.clear.should be(x)
    x << 1
    x.to_a.should eq([1])
  end

  it "checks intersects" do
    set = Set{3, 4, 5}
    empty_set = Set(Int32).new

    set.intersects?(set).should be_true
    set.intersects?(Set{2, 4}).should be_true
    set.intersects?(Set{5, 6, 7}).should be_true
    set.intersects?(Set{1, 2, 6, 8, 4}).should be_true

    set.intersects?(empty_set).should be_false
    set.intersects?(Set{0, 2}).should be_false
    set.intersects?(Set{0, 2, 6}).should be_false
    set.intersects?(Set{0, 2, 6, 8, 10}).should be_false

    # Make sure set hasn't changed
    set.should eq(Set{3, 4, 5})
  end

  it "compares hashes of sets" do
    h1 = {Set{1, 2, 3} => 1}
    h2 = {Set{1, 2, 3} => 1}
    h1.should eq(h2)
  end

  it "does each" do
    set = Set{1, 2, 3}
    i = 1
    set.each do |v|
      v.should eq(i)
      i += 1
    end.should be_nil
    i.should eq(4)
  end

  it "gets each iterator" do
    iter = Set{1, 2, 3}.each
    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should eq(3)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(1)
  end

  it "check subset" do
    set = Set{1, 2, 3}
    empty_set = Set(Int32).new

    set.subset?(Set{1, 2, 3, 4}).should be_true
    set.subset?(Set{1, 2, 3, "4"}).should be_true
    set.subset?(Set{1, 2, 3}).should be_true
    set.subset?(Set{1, 2}).should be_false
    set.subset?(empty_set).should be_false

    empty_set.subset?(Set{1}).should be_true
    empty_set.subset?(empty_set).should be_true
  end

  it "check proper_subset" do
    set = Set{1, 2, 3}
    empty_set = Set(Int32).new

    set.proper_subset?(Set{1, 2, 3, 4}).should be_true
    set.proper_subset?(Set{1, 2, 3, "4"}).should be_true
    set.proper_subset?(Set{1, 2, 3}).should be_false
    set.proper_subset?(Set{1, 2}).should be_false
    set.proper_subset?(empty_set).should be_false

    empty_set.proper_subset?(Set{1}).should be_true
    empty_set.proper_subset?(empty_set).should be_false
  end

  it "check superset" do
    set = Set{1, 2, "3"}
    empty_set = Set(Int32).new

    set.superset?(empty_set).should be_true
    set.superset?(Set{1, 2}).should be_true
    set.superset?(Set{1, 2, "3"}).should be_true
    set.superset?(Set{1, 2, 3}).should be_false
    set.superset?(Set{1, 2, 3, 4}).should be_false
    set.superset?(Set{1, 4}).should be_false

    empty_set.superset?(empty_set).should be_true
  end

  it "check proper_superset" do
    set = Set{1, 2, "3"}
    empty_set = Set(Int32).new

    set.proper_superset?(empty_set).should be_true
    set.proper_superset?(Set{1, 2}).should be_true
    set.proper_superset?(Set{1, 2, "3"}).should be_false
    set.proper_superset?(Set{1, 2, 3}).should be_false
    set.proper_superset?(Set{1, 2, 3, 4}).should be_false
    set.proper_superset?(Set{1, 4}).should be_false

    empty_set.proper_superset?(empty_set).should be_false
  end

  it "has object_id" do
    Set(Int32).new.object_id.should be > 0
  end

  typeof(Set(Int32).new(initial_capacity: 1234))
end
