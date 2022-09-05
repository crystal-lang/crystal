def it_acts_as_digest_algorithm(type : T.class) forall T
  it "#hexdigest can update within a loop from explicit expr (#9483)" do
    i = 0
    type.hexdigest do |digest|
      while i < 3
        digest.update("")
        i += 1
      end
    end
  end

  it "#hexdigest can update within a loop by indirect expr (#9483)" do
    algorithm = {} of String => ::Digest::ClassMethods
    algorithm["me"] = type
    i = 0
    algorithm["me"].hexdigest do |digest|
      while i < 3
        digest.update("")
        i += 1
      end
    end
  end

  it "context are independent" do
    algorithm = type
    res = algorithm.hexdigest do |digest|
      digest.update("a")
      digest.update("b")
    end

    inner_res = nil

    outer_res = algorithm.hexdigest do |outer|
      outer.update("a")

      inner_res = algorithm.hexdigest do |inner|
        inner.update("a")
        inner.update("b")
      end

      outer.update("b")
    end

    outer_res.should eq(res)
    inner_res.should eq(res)
  end

  describe ".dup" do
    it "preserves type" do
      type.new.dup.class.should eq(type)
    end

    it "preserves value" do
      digest1 = type.new
      digest1.update("a")
      digest2 = digest1.dup

      digest1.final.should eq(digest2.final)
    end

    it "leads to not sharing state" do
      digest1 = type.new
      digest1.update("a")

      digest2 = digest1.dup

      digest1.update("b")

      digest1.final.should_not eq(digest2.final)
    end

    it "leads to deterministic updates" do
      digest1 = type.new
      digest1.update("a")

      digest2 = digest1.dup

      digest1.update("b")
      digest2.update("b")

      digest1.final.should eq(digest2.final)
    end
  end

  it "digest with file content" do
    path = datapath("test_file.txt")
    type.new.file(path).final.should eq(type.digest(File.read(path)))
  end
end
