require "spec"
require "semantic_version"

describe SemanticVersion do
  it "compares <" do
    sversions = %w(
      1.2.3-2
      1.2.3-10
      1.2.3-alpha
      1.2.3-alpha.2
      1.2.3-alpha.10
      1.2.3-beta
      1.2.3
      1.2.4-alpha
      1.2.4-beta
      1.2.4
    )
    versions = sversions.map { |s| SemanticVersion.parse(s) }.to_a

    versions.each_with_index do |v, i|
      v.to_s.should eq(sversions[i])
    end

    versions.each_cons(2) do |pair|
      pair[0].should be < pair[1]
    end
  end

  it "compares build equivalence" do
    sversions = [
      "1.2.3+1",
      "1.2.3+999",
      "1.2.3+a",
    ]
    versions = sversions.map { |s| SemanticVersion.parse(s) }.to_a

    versions.each_with_index do |v, i|
      v.to_s.should eq(sversions[i])
    end

    versions.each_cons(2) do |pair|
      pair[0].should eq(pair[1])
    end
  end

  describe SemanticVersion::Prerelease do
    it "compares <" do
      sprereleases = %w[
        alpha.1
        beta.1
        beta.2
      ]
      prereleases = sprereleases.map { |s|
        SemanticVersion::Prerelease.parse(s)
      }

      prereleases.each_cons(2) do |pair|
        pair[0].should be < pair[1]
      end
    end
  end
end
