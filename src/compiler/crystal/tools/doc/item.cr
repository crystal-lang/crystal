module Crystal::Doc::Item
  include JSON::Serializable::Helper

  def formatted_doc
    @generator.doc(self)
  end

  def formatted_summary
    @generator.summary(self)
  end
end
