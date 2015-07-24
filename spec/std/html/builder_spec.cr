require "spec"
require "html/builder"

describe "HTML" do
  describe "Builder" do
    it "builds html" do
      str = HTML::Builder.new.build do
        doctype
        html do
          head do
            title { text "Crystal Programming Language" }
          end
          body do
            a({href: "http://crystal-lang.org"}) { text "Crystal rocks!" }
            form({method: "POST"}) do
              input({name: "name"})
            end
          end
        end
      end
      str.should eq %(<!DOCTYPE html><html><head><title>Crystal Programming Language</title></head><body><a href="http://crystal-lang.org">Crystal rocks!</a><form method="POST"><input name="name"></form></body></html>)
    end

    it "builds html with some tag attributes" do
      str = HTML::Builder.new.build do
        a({ href: "http://crystal-lang.org", class: "crystal", id: "main" }) do
          text "Crystal rocks!"
        end
      end
      str.should eq %(<a href="http://crystal-lang.org" class="crystal" id="main">Crystal rocks!</a>)
    end

    it "escapes attribute values" do
      str = HTML::Builder.new.build do
        a({href: "<>"}) {}
      end
      str.should eq %(<a href="&lt;&gt;"></a>)
    end

    it "escapes text" do
      str = HTML::Builder.new.build do
        a { text "<>" }
      end
      str.should eq %(<a>&lt;&gt;</a>)
    end
  end
end
