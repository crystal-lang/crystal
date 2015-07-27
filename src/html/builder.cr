require "html"

# HTML::Builder
#
# HTML::Builder is a library for representing HTML in Crystal.
#
# Usage:
#
# ```
# html = HTML::Builder.new.a({href: "google.com"}) do
#   text "crystal is awesome"
# end
#
# puts html # => "<a href="google.com">crystal is awesome</a>
# ```
#
# Or also you can use `build` method:
#
# ```
# HTML::Builder.new.build do
#   a({href: "google.com"}) do
#     text "crystal is awesome"
#   end
# end # => "<a href="google.com">crystal is awesome</a>
# ```
struct HTML::Builder
  def initialize
    @str = StringIO.new
  end

  def build
    with self yield self
    @str.to_s
  end

  # Renders `HTML` doctype tag.
  #
  # ```
  # HTML::Builder.new.build { doctype } # => <doctype/>
  # ```
  def doctype
    @str << "<!DOCTYPE html>"
  end

  # Renders `BR` html tag.
  #
  # ```
  # HTML::Builder.new.build { br } # => <br/>
  # ```
  def br
    @str << "<br/>"
  end

  # Renders `HR` html tag.
  #
  # ```
  # HTML::Builder.new.build { hr } # => <hr/>
  # ```
  def hr
    @str << "<hr/>"
  end

  # Renders escaped text in html tag.
  #
  # ```
  # HTML::Builder.new.build { text "crystal is awesome" }
  # # => crystal is awesome
  # ```
  def text(text)
    @str << HTML.escape(text)
  end

  {% for tag in %w(a b body button div em h1 h2 h3 head html i li ol p s script span strong table tbody td textarea thead title tr u ul form) %}
    # Renders `{{tag.id.upcase}}` html tag with any options.
    #
    # ```
    # HTML::Builder.new.build do
    #   {{tag.id}}({ class: "crystal" }) { text "crystal is awesome" }
    # end
    # # => <{{tag.id}} class="crystal">crystal is awesome</{{tag.id}}>
    # ```
    def {{tag.id}}(attrs = nil : Hash(Symbol, String)?)
      @str << "<{{tag.id}}"
      append_attributes_string(attrs)
      @str << ">"
      with self yield self
      @str << "</{{tag.id}}>"
    end
  {% end %}

  {% for tag in %w(link input img) %}
    # Renders `{{tag.id.upcase}}` html tag with any options.
    #
    # ```
    # HTML::Builder.new.build do
    #   {{tag.id}}({ class: "crystal" })
    # end
    # # => <{{tag.id}} class="crystal">
    # ```
    def {{tag.id}}(attrs = nil : Hash(Symbol, String)?)
      @str << "<{{tag.id}}"
      append_attributes_string(attrs)
      @str << ">"
    end
  {% end %}

  private def append_attributes_string(attrs : Hash(Symbol, String)?)
    if attrs
      attrs.each do |name, value|
        @str << " "
        @str << name
        @str << %(=")
        HTML.escape(value, @str)
        @str << %(")
      end
    end
  end
end
