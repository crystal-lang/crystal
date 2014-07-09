struct HTML::Builder
  def initialize
    @str = StringIO.new
  end

  def build
    with self yield self
    @str.to_s
  end

  {% for tag in %w(a b body div em h1 h2 h3 head html i img input li ol p s script span strong table tbody td textarea thead thead title tr u ul) %}
    def {{tag.id}}(attrs = nil : Hash?)
      @str << "<{{tag.id}}"
      if attrs
        @str << " "
        attrs.each do |name, value|
          @str << name
          @str << %(=")
          # TODO: escape html entities
          @str << value
          @str << %(")
        end
      end
      @str << ">"
      with self yield self
      @str << "</{{tag.id}}>"
    end
  {% end %}

  def br
    @str << "<br/>"
  end

  def hr
    @str << "<hr/>"
  end

  def text(text)
    @str << text
  end
end
