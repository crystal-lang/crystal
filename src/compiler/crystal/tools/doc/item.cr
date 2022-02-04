module Crystal::Doc::Item
  def formatted_doc
    @generator.doc(self)
  end

  def formatted_summary
    @generator.summary(self)
  end
end

enum Crystal::Doc::HTMLOption
  None
  Highlight
  All

  def highlight? : Bool
    self >= Highlight
  end

  def links? : Bool
    self >= All
  end
end
