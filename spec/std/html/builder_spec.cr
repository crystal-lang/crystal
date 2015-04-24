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
            form({method: "POST"}) do
              input({name: "name"}) {}
            end
          end
        end
      end
      expect(str).to eq %(<html><head><title>Crystal Programming Language</title></head><body><a href="http://crystal-lang.org">Crystal rocks!</a><form method="POST"><input name="name"></input></form></body></html>)
    end

    it "escapes attribute values" do
      str = HTML::Builder.new.build do
        a({href: "<>"}) {}
      end
      expect(str).to eq %(<a href="&lt;&gt;"></a>)
    end

    it "escapes text" do
      str = HTML::Builder.new.build do
        a { text "<>" }
      end
      expect(str).to eq %(<a>&lt;&gt;</a>)
    end
  end
end
