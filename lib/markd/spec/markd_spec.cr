require "./spec_helper"

# Commonmark spec examples
describe_spec("fixtures/spec.txt")

# Smart punctuation examples
describe_spec("fixtures/smart_punct.txt", smart: true)

# Regression examples
describe_spec("fixtures/regression.txt")

describe Markd do
  # Thanks Ryan Westlund <rlwestlund@gmail.com> feedback via email.
  it "should escape unsafe html" do
    raw = %Q{```"><script>window.location="https://footbar.com"</script>\n```}
    html = %Q{<pre><code class="language-&quot;&gt;&lt;script&gt;window.location=&quot;https://footbar.com&quot;&lt;/script&gt;"></code></pre>\n}

    Markd.to_html(raw).should eq(html)
  end
end
