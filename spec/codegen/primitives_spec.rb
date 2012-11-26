require 'spec_helper'

describe 'Code gen: primitives' do
  it 'codegens bool' do
    run('true').to_b.should be_true
  end

  it 'codegens int' do
    run('1').to_i.should eq(1)
  end

  it 'codegens long' do
    run('1L').to_i.should eq(1)
  end

  it 'codegens float' do
    run('1; 2.5').to_f.should eq(2.5)
  end

  it 'codegens char' do
    run("'a'").to_i.should eq(?a.ord)
  end

  it 'codegens string' do
    run('"foo".length').to_i.should eq("foo".size)
  end

  it 'codegens string concatenation' do
    run('("foo" + "bar").length').to_i.should eq(6)
  end

  it 'codegens string indexer' do
    run('"foo"[1]').to_i.should eq(?o.ord)
  end

  it 'codegens symbol' do
    run(':foo').to_i.should eq(0)
  end

  it 'codegens Symbol == Symbol' do
    run(':foo == :foo').to_b.should be_true
    run(':foo == :bar').to_b.should be_false
  end

  it 'codegens Symbol != Symbol' do
    run(':foo != :foo').to_b.should be_false
    run(':foo != :bar').to_b.should be_true
  end

  it 'codegens int method' do
    run('class Int; def foo; 3; end; end; 1.foo').to_i.should eq(3)
  end

  it 'codegens int method with clashing name in global scope' do
    run('def foo; 5; end; class Int; def foo; 2; end; end; 1.foo; foo').to_i.should eq(5)
  end

  it "codegens !Bool -> true" do
    run('!false').to_b.should be_true
  end

  it "codegens !Bool -> false" do
    run('!true').to_b.should be_false
  end

  it "codegens Bool && Bool -> true" do
    run('true && true').to_b.should be_true
  end

  it "codegens Bool && Bool -> false" do
    run('true && false').to_b.should be_false
  end

  it "codegens Bool || Bool -> false" do
    run('false || false').to_b.should be_false
  end

  it "codegens Bool || Bool -> true" do
    run('false || true').to_b.should be_true
  end

  it 'codegens - Int' do
    run('- 1').to_i.should eq(-1)
  end

  it 'codegens + Int' do
    run('+ 1').to_i.should eq(1)
  end

  it 'codegens Int + Int' do
    run('1 + 2').to_i.should eq(3)
  end

  it 'codegens Int - Int' do
    run('1 - 2').to_i.should eq(-1)
  end

  it 'codegens Int * Int' do
    run('2 * 3').to_i.should eq(6)
  end

  it 'codegens Int / Int' do
    run('7 / 3').to_i.should eq(2)
  end

  it 'codegens Int + Float' do
    run('1 + 1.5').to_f.should eq(2.5)
  end

  it 'codegens Int - Float' do
    run('3 - 0.5').to_f.should eq(2.5)
  end

  it 'codegens Int * Float' do
    run('2 * 1.25').to_f.should eq(2.5)
  end

  it 'codegens Int / Float' do
    run('5 / 2.0').to_f.should eq(2.5)
  end

  it 'codegens Int % Int' do
    run('8 % 3').to_i.should eq(2)
  end

  it 'codegens Float + Float' do
    run('1.0 + 1.5').to_f.should eq(2.5)
  end

  it 'codegens Float - Float' do
    run('3.0 - 0.5').to_f.should eq(2.5)
  end

  it 'codegens Float * Float' do
    run('2.0 * 1.25').to_f.should eq(2.5)
  end

  it 'codegens Float / Float' do
    run('5.0 / 2.0').to_f.should eq(2.5)
  end

  it 'codegens Float + Int' do
    run('1.5 + 1').to_f.should eq(2.5)
  end

  it 'codegens Float - Int' do
    run('3.5 - 1').to_f.should eq(2.5)
  end

  it 'codegens Float * Int' do
    run('1.25 * 2').to_f.should eq(2.5)
  end

  it 'codegens Float / Int' do
    run('5.0 / 2').to_f.should eq(2.5)
  end

  [['Int', ''], ['Float', '.0']].each do |type1, suffix1|
    [['Int', ''], ['Float', '.0']].each do |type2, suffix2|
      it 'codegens #{type1} == #{type2} gives false' do
        run("1#{suffix1} == 2#{suffix2}").to_b.should be_false
      end

      it 'codegens #{type1} == #{type2} gives true' do
        run("1#{suffix1} == 1#{suffix2}").to_b.should be_true
      end

      it 'codegens #{type1} != #{type2} gives false' do
        run("1#{suffix1} != 1#{suffix2}").to_b.should be_false
      end

      it 'codegens #{type1} != #{type2} gives true' do
        run("1#{suffix1} != 2#{suffix2}").to_b.should be_true
      end

      it 'codegens #{type1} < #{type2} gives false' do
        run("2#{suffix1} < 1#{suffix2}").to_b.should be_false
      end

      it 'codegens #{type1} < #{type2} gives true' do
        run("1#{suffix1} < 2#{suffix2}").to_b.should be_true
      end

      it 'codegens #{type1} <= #{type2} gives false' do
        run("2#{suffix1} <= 1#{suffix2}").to_b.should be_false
      end

      it 'codegens #{type1} <= #{type2} gives true' do
        run("1#{suffix1} <= 1#{suffix2}").to_b.should be_true
        run("1#{suffix1} <= 2#{suffix2}").to_b.should be_true
      end

      it 'codegens #{type1} > #{type2} gives false' do
        run("1#{suffix1} > 2#{suffix2}").to_b.should be_false
      end

      it 'codegens #{type1} > #{type2} gives true' do
        run("2#{suffix1} > 1#{suffix2}").to_b.should be_true
      end

      it 'codegens #{type1} >= #{type2} gives false' do
        run("1#{suffix1} >= 2#{suffix2}").to_b.should be_false
      end

      it 'codegens #{type1} >= #{type2} gives true' do
        run("1#{suffix1} >= 1#{suffix2}").to_b.should be_true
        run("2#{suffix1} >= 1#{suffix2}").to_b.should be_true
      end
    end
  end

  it 'codegens Char == Char gives true' do
    run("'a' == 'a'").to_b.should be_true
  end

  it 'codegens Char == Char gives false' do
    run("'a' == 'b'").to_b.should be_false
  end

  it 'codegens Char != Char gives true' do
    run("'a' != 'b'").to_b.should be_true
  end

  it 'codegens Char != Char gives false' do
    run("'a' != 'a'").to_b.should be_false
  end

  it 'codegens Char < Char gives true' do
    run("'a' < 'b'").to_b.should be_true
  end

  it 'codegens Char < Char gives false' do
    run("'b' < 'a'").to_b.should be_false
  end

  it 'codegens Char <= Char gives true' do
    run("'a' <= 'a'").to_b.should be_true
    run("'a' <= 'b'").to_b.should be_true
  end

  it 'codegens Char <= Char gives false' do
    run("'b' <= 'a'").to_b.should be_false
  end

  it 'codegens Char > Char gives true' do
    run("'b' > 'a'").to_b.should be_true
  end

  it 'codegens Char > Char gives false' do
    run("'a' > 'b'").to_b.should be_false
  end

  it 'codegens Char >= Char gives true' do
    run("'b' >= 'b'").to_b.should be_true
    run("'b' >= 'a'").to_b.should be_true
  end

  it 'codegens Char >= Char gives false' do
    run("'a' >= 'b'").to_b.should be_false
  end

  it 'codegens Int#chr' do
    run("65.chr").to_i.should eq(65)
  end

  it 'codegens Char#ord' do
    run("'A'.ord").to_i.should eq(65)
    run("255.chr.ord").to_i.should eq(255)
  end

  it "codegens Int#to_i" do
    run("1.to_i").to_i.should eq(1)
  end

  it "codegens Int#to_f" do
    run("1.to_f").to_f.should eq(1.0)
  end

  it "codegens Float#to_i" do
    run("2.5.to_i").to_i.should eq(2)
  end

  it "codegens Float#to_f" do
    run("2.5.to_f").to_f.should eq(2.5)
  end
end
