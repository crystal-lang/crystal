require "spec"

describe "ENV" do
  it "gets non existent key raises" do
    expect_raises MissingKey, "Missing ENV key: NON-EXISTENT" do
      ENV["NON-EXISTENT"]
    end
  end

  it "gets non existent key as nilable" do
    expect(ENV["NON-EXISTENT"]?).to be_nil
  end

  it "set and gets" do
    ENV["FOO"] = "1"
    expect(ENV["FOO"]).to eq("1")
    expect(ENV["FOO"]?).to eq("1")
  end

  it "does has_key?" do
    ENV["FOO"] = "1"
    expect(ENV.has_key?("BAR")).to be_false
    expect(ENV.has_key?("FOO")).to be_true
  end

  it "deletes a key" do
    ENV["FOO"] = "1"
    expect(ENV.delete("FOO")).to eq("1")
    expect(ENV.delete("FOO")).to be_nil
    expect(ENV.has_key?("FOO")).to be_false
  end
end
