describe "StringBuilder" do
  it "concatenates two strings" do
    builder = StringBuilder.new
    builder.append "hello"
    builder.append "world"
    builder.to_s.should eq("helloworld")
  end
end