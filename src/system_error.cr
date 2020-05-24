# This module can be included in any `Exception` subclass that is
# used to wrap some system error (`Errno` or `WinError`)
#
# When included it provides a `from_errno` method (and `from_winerror` on Windows)
# to create exception instances with a description of the original error. It also
# adds an `os_error` property that contains the original system error.
#
# For example:
# ```
# class MyError < Exception
#   include SystemError
# end
#
# MyError.from_errno("Something happened")
# ```
module SystemError
  macro included
    extend ::SystemError::ClassMethods
  end

  # The original system error wrapped by this exception
  {% if flag?(:windows) %}
    getter os_error : Errno | WinError | Nil
  {% else %}
    getter os_error : Errno?
  {% end %}

  # :nodoc:
  protected def os_error=(@os_error)
  end

  module ClassMethods
    # Builds an instance of the exception from a `Errno`
    #
    # By default it takes the current `errno` value. The `message` is appended
    # with the system message corresponding to the `errno`.
    # Additional keyword arguments can be passed and they will be forwarded
    # to the exception initializer
    def from_errno(message : String? = nil, errno : Errno = Errno.value, **opts)
      message = self.build_message(message, **opts)
      message =
        if message
          "#{message}: #{errno.message}"
        else
          errno.message
        end

      self.new_from_errno(message, errno, **opts).tap do |e|
        e.os_error = errno
      end
    end

    # Prepare the message that goes before the system error description
    #
    # By default it returns the original message unchanged. But that could be
    # customized based on the keyword arguments passed to `from_errno` or `from_winerror`.
    protected def build_message(message, **opts)
      message
    end

    # Create an instance of the exception that wraps a system error
    #
    # This is a factory method and by default it creates an instance
    # of the current class. It can be overrided to generate different
    # classes based on the `errno` or keyword arguments.
    protected def new_from_errno(message : String, errno : Errno, **opts)
      self.new(message, **opts)
    end

    {% if flag?(:win32) %}
      # Builds an instance of the exception from a `WinError`
      #
      # By default it takes the current `WinError` value. The `message` is appended
      # with the system message corresponding to the `WinError`.
      # Additional keyword arguments can be passed and they will be forwarded
      # to the exception initializer
      def from_winerror(message : String? = nil, winerror : WinError = WinError.value, **opts)
        message = self.build_message(message, **opts)
        message =
          if message
            "#{message}: #{winerror.message}"
          else
            winerror.message
          end

        self.new_from_winerror(message, winerror, **opts).tap do |e|
          e.os_error = winerror
        end
      end

      # Create an instance of the exception that wraps a system error
      #
      # This is a factory method and by default it creates an instance
      # of the current class. It can be overrided to generate different
      # classes based on the `winerror` or keyword arguments.
      protected def new_from_winerror(message : String, winerror : WinError, **opts)
        new_from_errno(message, winerror.to_errno, **opts)
      end
    {% end %}
  end
end
