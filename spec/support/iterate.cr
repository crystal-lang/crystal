# spec helper for generic iteration methods which tests both yielding and
# iterator overloads.
macro it_iterates(description, expected, method, *, infinite = false)
  describe {{ description }} do
    it "yielding" do
      remaining = ({{ expected }}).size
      ary = [] of typeof(({{ expected }})[0])
      {{ method.id }} do |x|
        if remaining == 0
          if {{ infinite }}
            break
          else
            fail "Reached iteration limit #{({{ expected }}).size} receiving value #{x.inspect}"
          end
        end

        ary << x
        remaining -= 1
      end

      ary.should eq {{ expected }}
      ary.zip({{ expected }}).each_with_index do |(a, b), i|
        if a.class != b.class
          fail "mismatching type, expected: #{a.class}, got: #{b.class} at #{i} (value: #{a})"
        end
      end
    end

    it "iterator" do
      ary = [] of typeof(({{ expected }})[0])
      iter = {{ method.id }}
      ({{ expected }}).size.times do
        v = iter.next
        break if v.is_a?(Iterator::Stop)
        ary << v
      end
      unless {{ infinite }}
        iter.next.should be_a(Iterator::Stop)
      end

      ary.should eq {{ expected }}
      ary.zip({{ expected }}).each_with_index do |(a, b), i|
        if a.class != b.class
          fail "mismatching type, expected: #{b.class}, got: #{a.class} at #{i} (value: #{a})"
        end
      end
    end
  end
end
