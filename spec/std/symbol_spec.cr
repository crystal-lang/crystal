require "spec"

describe Symbol do
  it "inspects" do
    expect(:foo.inspect).to eq(%(:foo))
    expect(:"{".inspect).to eq(%(:"{"))
    expect(:"hi there".inspect).to eq(%(:"hi there"))
    expect(# :かたな.inspect).to eq(%(:かたな))
  end
  
  it "can be compared with another symbol" do
    expect(:s.between?(:a, :z)).to be_true
    expect(:a.between?(:s, :z)).to be_false
    expect((:foo > :bar)).to be_true
    expect((:foo < :bar)).to be_false

    a = %i(q w e r t y u i o p a s d f g h j k l z x c v b n m)
    b = %i(a b c d e f g h i j k l m n o p q r s t u v w x y z)
    expect(a.sort).to eq(b)
  end

  it "displays symbols that don't need quotes without quotes" do
    a = %i(+ - * / == < <= > >= ! != =~ !~ & | ^ ~ ** >> << % [] <=> === []? []=)
    b = "[:+, :-, :*, :/, :==, :<, :<=, :>, :>=, :!, :!=, :=~, :!~, :&, :|, :^, :~, :**, :>>, :<<, :%, :[], :<=>, :===, :[]?, :[]=]"
    expect(a.inspect).to eq(b)
  end
end
