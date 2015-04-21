require "../../spec_helper"

describe "Code gen: case" do
  it "codegens case with one condition" do
    expect(run("require \"object\"; case 1; when 1; 2; else; 3; end").to_i).to eq(2)
  end

  it "codegens case with two conditions" do
    expect(run("require \"object\"; case 1; when 0, 1; 2; else; 3; end").to_i).to eq(2)
  end

  it "codegens case with else" do
    expect(run("require \"object\"; case 1; when 0; 2; else; 3; end").to_i).to eq(3)
  end

  it "codegens case that always returns" do
    expect(run("
      require \"object\"
      def foo
        if true
          case 0
          when 1; return 2
          else return 3
          end
        end
        4
      end

      foo
    ").to_i).to eq(3)
  end

  it "codegens case when cond is a call" do
    expect(run("
      require \"object\"

      $a = 0

      def foo
        $a += 1
      end

      case foo
      when 2
        1
      when 1
        2
      else
        3
      end
    ").to_i).to eq(2)
  end

  it "codegens case with class" do
    expect(run("
      require \"nil\"
      struct Int32
        def foo
          self
        end
      end

      a = -1 || 'a'
      case a
      when Int32
        a.foo
      when Char
        a.ord
      end.to_i
      ").to_i).to eq(-1)
  end

  it "codegens value-less case" do
    expect(run("
      case
      when 1 == 2
        1
      when 2 == 2
        2
      else
        3
      end
      ").to_i).to eq(2)
  end
end
