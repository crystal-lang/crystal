module Crystal::Doc::Item
  def formatted_doc
    @generator.doc(self)
  end

  def formatted_summary
    @generator.summary(self)
  end

  def highlight(code)
    @generator.highlight(code)
  end
end
