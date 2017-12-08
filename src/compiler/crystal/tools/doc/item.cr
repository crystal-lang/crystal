module Crystal::Doc::Item
  getter generator : Crystal::Doc::Generator

  def formatted_doc
    @generator.doc(self)
  end

  def formatted_summary
    @generator.summary(self)
  end
end
