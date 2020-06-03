require "compress/deflate"

{% puts "Warning: Flate is deprecated, use Compress::Deflate" %}

# DEPRECATED: Use `Compress::Deflate`
alias Flate = Compress::Deflate
