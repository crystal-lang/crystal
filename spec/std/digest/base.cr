macro acts_as_digest_base(type)
  it "#hexdigest can update within a loop from explicit type (#9483)" do
    i = 0
    {{type}}.hexdigest do |digest|
      while i < 3
        digest.update("")
        i += 1
      end
    end
  end

  it "#hexdigest can update within a loop by indirect type (#9483)" do
    algorithm = {} of String => Digest::Base.class
    algorithm["me"] = {{type}}
    i = 0
    algorithm["me"].hexdigest do |digest|
      while i < 3
        digest.update("")
        i += 1
      end
    end
  end
end
