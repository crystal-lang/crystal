require 'spec_helper'

describe 'Code gen: var' do
  it 'codegens var' do
    run('a = 1; 1.5; a').to_i.should eq(1)
  end

  it 'codegens ivar assignment when not-nil type filter applies' do
    run(%q(
      class Foo
        def foo
          if @a
            x = @a
          end
          @a = 2
        end
      end

      foo = Foo.new
      foo.foo
      )).to_i.should eq(2)
  end
end
