require "spec"

describe Symbol do
  it "inspects" do
    :foo.inspect.should eq(%(:foo))
    :"{".inspect.should eq(%(:"{"))
    :"hi there".inspect.should eq(%(:"hi there"))
    :"1a".inspect.should eq(%(:"1a"))
    # :かたな.inspect.should eq(%(:かたな))
  end

  it "can be compared with another symbol" do
    (:foo > :bar).should be_true
    (:foo < :bar).should be_false

    a = %i(q w e r t y u i o p a s d f g h j k l z x c v b n m)
    b = %i(a b c d e f g h i j k l m n o p q r s t u v w x y z)
    a.sort.should eq(b)
  end

  it "displays symbols that don't need quotes without quotes" do
    a = %i(+ - * / == < <= > >= ! != =~ !~ & | ^ ~ ** &** >> << % [] <=> === []? []=)
    b = "[:+, :-, :*, :/, :==, :<, :<=, :>, :>=, :!, :!=, :=~, :!~, :&, :|, :^, :~, :**, :&**, :>>, :<<, :%, :[], :<=>, :===, :[]?, :[]=]"
    a.inspect.should eq(b)
  end

  it "displays the empty symbol with quotes" do
    :"".inspect.should eq(%(:""))
  end

  describe "clone" do
    it { :foo.clone.should eq(:foo) }
  end
end
