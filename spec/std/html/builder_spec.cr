require "spec"
require "html/builder"

describe "HTML" do
  describe "Builder" do
    it "builds html" do
      str = HTML::Builder.new.build do
        html do
          head do
            title { text "Crystal Programming Language" }
          end
          body do
            a({href: "http://crystal-lang.org"}) { text "Crystal rocks!" }
          end
        end
      end
      str.should eq %(<html><head><title>Crystal Programming Language</title></head><body><a href="http://crystal-lang.org">Crystal rocks!</a></body></html>)
    end
  end
end
