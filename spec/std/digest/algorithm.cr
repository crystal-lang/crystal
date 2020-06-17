macro acts_as_digest_algorithm(expr)
  it "#hexdigest can update within a loop from explicit expr (#9483)" do
    %i = 0
    {{expr}}.hexdigest do |%digest|
      while %i < 3
        %digest.update("")
        %i += 1
      end
    end
  end

  it "#hexdigest can update within a loop by indirect expr (#9483)" do
    %algorithm = {} of String => Digest::Algorithm.class
    %algorithm["me"] = {{expr}}
    %i = 0
    %algorithm["me"].hexdigest do |%digest|
      while %i < 3
        %digest.update("")
        %i += 1
      end
    end
  end

  it "context are independent" do
    %algorithm = {{expr}}
    %res = %algorithm.hexdigest do |%digest|
      %digest.update("a")
      %digest.update("b")
    end

    %inner_res = nil

    %outer_res = %algorithm.hexdigest do |%outer|
      %outer.update("a")

      %inner_res = %algorithm.hexdigest do |%inner|
        %inner.update("a")
        %inner.update("b")
      end

      %outer.update("b")
    end

    %outer_res.should eq(%res)
    %inner_res.should eq(%res)
  end
end
