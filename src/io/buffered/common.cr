# The BufferedIO mixin enhances the IO module with input/output buffering.
#
# The buffering behaviour can be turned on/off with the `#sync=` method.
#
# Additionally, several methods, like `#gets`, are implemented in a more
# efficient way.
module IO::Buffered::Common
  include IO

  BUFFER_SIZE = 8192

  # Due to https://github.com/manastech/crystal/issues/456 this
  # initialization logic must be copied in the included type's
  # initialize method:
  #
  # def initialize
  #   @out_count = 0
  # end

  # Closes the wrapped IO.
  abstract def unbuffered_close

  # Flushes and closes the underlying IO.
  def close
    flush if responds_to?(:flush) && @out_count > 0
    unbuffered_close
  end
end
