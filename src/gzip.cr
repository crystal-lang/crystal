require "compress/gzip"

{% puts "Warning: Gzip is deprecated, use Compress::Gzip" %}

# DEPRECATED: Use `Compress::Gzip`
alias Gzip = Compress::Gzip
