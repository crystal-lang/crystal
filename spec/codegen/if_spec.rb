require 'spec_helper'

describe 'Code gen: if' do
  it 'codegens if without an else with true' do
    run('a = 1; if true; a = 2; end; a').to_i.should eq(2)
  end

  it 'codegens if without an else with false' do
    run('a = 1; if false; a = 2; end; a').to_i.should eq(1)
  end

  it 'codegens if with an else with false' do
    run('a = 1; if false; a = 2; else; a = 3; end; a').to_i.should eq(3)
  end

  it 'codegens if with an else with true' do
    run('a = 1; if true; a = 2; else; a = 3; end; a').to_i.should eq(2)
  end

  it 'codegens if inside def without an else with true' do
    run('def foo; a = 1; if true; a = 2; end; a; end; foo').to_i.should eq(2)
  end

  it 'codegen if inside if' do
    run('a = 1; if false; a = 1; elsif false; a = 2; else; a = 3; end; a').to_i.should eq(3)
  end

  it 'codegens if value from then' do
    run('if true; 1; else 2; end').to_i.should eq(1)
  end

  it 'codegens if with union' do
    run('a = if true; 2.5f; else; 1; end; a.to_f').to_f.should eq(2.5)
  end

  it 'codes if with two whiles' do
    run('if true; while false; end; else; while false; end; end')
  end

  it 'codegens if with int' do
    run('require "object"; if 1; 2; else 3; end').to_i.should eq(2)
  end

  it 'codegens if with nil' do
    run('require "nil"; if nil; 2; else 3; end').to_i.should eq(3)
  end

  it 'codegens if of nilable type in then' do
    run('if false; nil; else; "foo"; end').to_string.should eq("foo")
  end

  it 'codegens if of nilable type in else' do
    run('if true; "foo"; else; nil; end').to_string.should eq("foo")
  end

  it "codegens if with return and no else" do
    run('def foo; if true; return 1; end; 2; end; foo').to_i.should eq(1)
  end

  it "codegens if with return in both branches" do
    run('def foo; if true; return 1; else; return 2; end; end; foo').to_i.should eq(1)
  end

  it "codegen if with nested if that returns" do
    run(%q(
      def foo
        if true
          if true
            return 1
          else
            return 2
          end
        end
        0
      end

      foo
    )).to_i.should eq(1)
  end
end
