require "../../../spec_helper"

describe Crystal::Doc::Generator do
  describe ".anchor_link" do
    it "generates the correct anchor link" do
      Crystal::Doc.anchor_link("anchor").should eq(
        <<-ANCHOR
        <a id="anchor" class="anchor" href="#anchor">
          <svg class="octicon-link" aria-hidden="true">
            <use href="#octicon-link"/>
          </svg>
        </a>
        ANCHOR
      )
    end
  end
end
