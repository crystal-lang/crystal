require "html"

struct HTML::Builder
  def initialize
    @str = StringIO.new
  end

  def build
    with self yield self
    @str.to_s
  end

  {% for tag in %w(a b body button div em h1 h2 h3 head html i img input li link ol p s script span strong table tbody td textarea thead thead title tr u ul form) %}
    def {{tag.id}}(attrs = nil : Hash?)
      @str << "<{{tag.id}}"
      if attrs
        @str << " "
        attrs.each do |name, value|
          @str << name
          @str << %(=")
          HTML.escape(value, @str)
          @str << %(")
        end
      end
      @str << ">"
      with self yield self
      @str << "</{{tag.id}}>"
    end
  {% end %}

  def doctype
    @str << "<!DOCTYPE html>"
  end

  def br
    @str << "<br/>"
  end

  def hr
    @str << "<hr/>"
  end

  def text(text)
    @str << HTML.escape(text)
  end
end
