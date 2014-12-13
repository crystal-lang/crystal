require "../../spec_helper"

describe "Code gen: no return" do
  it "codegens if with NoReturn on then and union on else" do
    run("lib C; fun exit(c : Int32) : NoReturn; end; (if 1 == 2; C.exit(1); else; 1 || 2.5; end).to_i").to_i.should eq(1)
  end

  it "codegens Pointer(NoReturn).malloc" do
    run("Pointer(NoReturn).malloc(1_u64); 1").to_i.should eq(1)
  end

  it "codegens if with no reutrn and variable used afterwards" do
    build(%(
      require "prelude"

      lib C
        fun exit2 : NoReturn
      end

      if (a = C.exit2) && a.length == 3
      end
      ))
  end
end
