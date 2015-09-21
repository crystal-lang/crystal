require "spec"
require "http/form"

module HTTP
  describe Form do
    describe ".parse" do
      [
        { "foo=bar", {"foo" => ["bar"]} },
        { "foo=bar&foo=baz", {"foo" => ["bar", "baz"]} },
        { "foo=bar&baz=qux", {"foo" => ["bar"], "baz" => ["qux"]} },
        { "foo=bar;baz=qux", {"foo" => ["bar"], "baz" => ["qux"]} },
        { "foo=hello%2Bworld", {"foo" => ["hello+world"]} },
        { "foo=", {"foo" => [""]} },
        { "foo", {"foo" => [""]} },
        { "foo=&bar", { "foo" => [""], "bar" => [""] } },
        { "bar&foo", { "bar" => [""], "foo" => [""] } },
      ].each do |tuple|
        from, to = tuple

        it "parses #{from}" do
          Form.parse(from).should eq(to)
        end
      end
    end

    describe ".build" do
      [
        { "foo=bar", {"foo" => ["bar"]} },
        { "foo=bar&foo=baz", {"foo" => ["bar", "baz"]} },
        { "foo=bar&baz=qux", {"foo" => ["bar"], "baz" => ["qux"]} },
        { "foo=hello%2Bworld", {"foo" => ["hello+world"]} },
        { "foo=", {"foo" => [""]} },
        { "foo=&bar=", { "foo" => [""], "bar" => [""] } },
        { "bar=&foo=", { "bar" => [""], "foo" => [""] } },
      ].each do |tuple|
        to, from = tuple

        it "builds form from #{from}" do
          encoded = Form.build do |form|
            from.each do |key, values|
              values.each do |value|
                form.add(key, value)
              end
            end
          end

          encoded.should eq(to)
        end
      end
    end
  end
end
