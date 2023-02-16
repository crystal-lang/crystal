# An enum that provides additional support around HTTP status codes.
#
# Based on [Hypertext Transfer Protocol (HTTP) Status Code Registry](https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml)
#
# It provides constants for the defined HTTP status codes as well as helper
# methods to easily identify the type of response.
#
# NOTE: To use `Status`, you must explicitly import it with `require "http/status"`
enum HTTP::Status
  CONTINUE                        = 100
  SWITCHING_PROTOCOLS             = 101
  PROCESSING                      = 102
  EARLY_HINTS                     = 103
  OK                              = 200
  CREATED                         = 201
  ACCEPTED                        = 202
  NON_AUTHORITATIVE_INFORMATION   = 203
  NO_CONTENT                      = 204
  RESET_CONTENT                   = 205
  PARTIAL_CONTENT                 = 206
  MULTI_STATUS                    = 207
  ALREADY_REPORTED                = 208
  IM_USED                         = 226
  MULTIPLE_CHOICES                = 300
  MOVED_PERMANENTLY               = 301
  FOUND                           = 302
  SEE_OTHER                       = 303
  NOT_MODIFIED                    = 304
  USE_PROXY                       = 305
  SWITCH_PROXY                    = 306
  TEMPORARY_REDIRECT              = 307
  PERMANENT_REDIRECT              = 308
  BAD_REQUEST                     = 400
  UNAUTHORIZED                    = 401
  PAYMENT_REQUIRED                = 402
  FORBIDDEN                       = 403
  NOT_FOUND                       = 404
  METHOD_NOT_ALLOWED              = 405
  NOT_ACCEPTABLE                  = 406
  PROXY_AUTHENTICATION_REQUIRED   = 407
  REQUEST_TIMEOUT                 = 408
  CONFLICT                        = 409
  GONE                            = 410
  LENGTH_REQUIRED                 = 411
  PRECONDITION_FAILED             = 412
  PAYLOAD_TOO_LARGE               = 413
  URI_TOO_LONG                    = 414
  UNSUPPORTED_MEDIA_TYPE          = 415
  RANGE_NOT_SATISFIABLE           = 416
  EXPECTATION_FAILED              = 417
  IM_A_TEAPOT                     = 418
  MISDIRECTED_REQUEST             = 421
  UNPROCESSABLE_ENTITY            = 422
  LOCKED                          = 423
  FAILED_DEPENDENCY               = 424
  UPGRADE_REQUIRED                = 426
  PRECONDITION_REQUIRED           = 428
  TOO_MANY_REQUESTS               = 429
  REQUEST_HEADER_FIELDS_TOO_LARGE = 431
  UNAVAILABLE_FOR_LEGAL_REASONS   = 451
  INTERNAL_SERVER_ERROR           = 500
  NOT_IMPLEMENTED                 = 501
  BAD_GATEWAY                     = 502
  SERVICE_UNAVAILABLE             = 503
  GATEWAY_TIMEOUT                 = 504
  HTTP_VERSION_NOT_SUPPORTED      = 505
  VARIANT_ALSO_NEGOTIATES         = 506
  INSUFFICIENT_STORAGE            = 507
  LOOP_DETECTED                   = 508
  NOT_EXTENDED                    = 510
  NETWORK_AUTHENTICATION_REQUIRED = 511

  # Create a new status instance with the given status code, or raise an
  # error if the status code given is not inside 100..999.
  #
  # ```
  # require "http/status"
  #
  # HTTP::Status.new(100)  # => HTTP::Status::CONTINUE
  # HTTP::Status.new(202)  # => HTTP::Status::ACCEPTED
  # HTTP::Status.new(123)  # => 123
  # HTTP::Status.new(1000) # raises ArgumentError
  # ```
  def self.new(status_code : Int32)
    raise ArgumentError.new("Invalid HTTP status code: #{status_code}") unless 100 <= status_code <= 999
    previous_def(status_code)
  end

  # Returns the number that represents the HTTP status code.
  #
  # ```
  # require "http/status"
  #
  # status = HTTP::Status::NO_CONTENT
  # status.code # => 204
  # ```
  def code : Int32
    value
  end

  # Returns `true` if the response status code is between 100 and 199.
  #
  # ```
  # require "http/status"
  #
  # HTTP::Status::SWITCHING_PROTOCOLS.informational?   # => true
  # HTTP::Status::INTERNAL_SERVER_ERROR.informational? # => false
  # ```
  def informational? : Bool
    100 <= code <= 199
  end

  # Returns `true` if the response status code is between 200 and 299.
  #
  # ```
  # require "http/status"
  #
  # HTTP::Status::NO_CONTENT.success?            # => true
  # HTTP::Status::INTERNAL_SERVER_ERROR.success? # => false
  # ```
  def success? : Bool
    200 <= code <= 299
  end

  # Returns `true` if the response status code is between 300 and 399.
  #
  # ```
  # require "http/status"
  #
  # HTTP::Status::SWITCH_PROXY.redirection?          # => true
  # HTTP::Status::INTERNAL_SERVER_ERROR.redirection? # => false
  # ```
  def redirection? : Bool
    300 <= code <= 399
  end

  # Returns `true` if the response status code is between 400 and 499.
  #
  # ```
  # require "http/status"
  #
  # HTTP::Status::METHOD_NOT_ALLOWED.client_error?    # => true
  # HTTP::Status::INTERNAL_SERVER_ERROR.client_error? # => false
  # ```
  def client_error? : Bool
    400 <= code <= 499
  end

  # Returns `true` if the response status code is between 500 and 599.
  #
  # ```
  # require "http/status"
  #
  # HTTP::Status::INTERNAL_SERVER_ERROR.server_error? # => true
  # HTTP::Status::METHOD_NOT_ALLOWED.server_error?    # => false
  # ```
  def server_error? : Bool
    500 <= code <= 599
  end

  # Returns the default status description of the given HTTP status code.
  #
  # ```
  # require "http/status"
  #
  # HTTP::Status.new(123).description               # => nil
  # HTTP::Status::NO_CONTENT.description            # => "No Content"
  # HTTP::Status::METHOD_NOT_ALLOWED.description    # => "Method Not Allowed"
  # HTTP::Status::INTERNAL_SERVER_ERROR.description # => "Internal Server Error"
  # ```
  def description : String?
    case code
    when 100 then "Continue"
    when 101 then "Switching Protocols"
    when 102 then "Processing"
    when 200 then "OK"
    when 201 then "Created"
    when 202 then "Accepted"
    when 203 then "Non-Authoritative Information"
    when 204 then "No Content"
    when 205 then "Reset Content"
    when 206 then "Partial Content"
    when 207 then "Multi-Status"
    when 208 then "Already Reported"
    when 226 then "IM Used"
    when 300 then "Multiple Choices"
    when 301 then "Moved Permanently"
    when 302 then "Found"
    when 303 then "See Other"
    when 304 then "Not Modified"
    when 305 then "Use Proxy"
    when 306 then "Switch Proxy"
    when 307 then "Temporary Redirect"
    when 308 then "Permanent Redirect"
    when 400 then "Bad Request"
    when 401 then "Unauthorized"
    when 402 then "Payment Required"
    when 403 then "Forbidden"
    when 404 then "Not Found"
    when 405 then "Method Not Allowed"
    when 406 then "Not Acceptable"
    when 407 then "Proxy Authentication Required"
    when 408 then "Request Timeout"
    when 409 then "Conflict"
    when 410 then "Gone"
    when 411 then "Length Required"
    when 412 then "Precondition Failed"
    when 413 then "Payload Too Large"
    when 414 then "URI Too Long"
    when 415 then "Unsupported Media Type"
    when 416 then "Range Not Satisfiable"
    when 417 then "Expectation Failed"
    when 418 then "I'm a teapot"
    when 421 then "Misdirected Request"
    when 422 then "Unprocessable Entity"
    when 423 then "Locked"
    when 424 then "Failed Dependency"
    when 426 then "Upgrade Required"
    when 428 then "Precondition Required"
    when 429 then "Too Many Requests"
    when 431 then "Request Header Fields Too Large"
    when 451 then "Unavailable For Legal Reasons"
    when 500 then "Internal Server Error"
    when 501 then "Not Implemented"
    when 502 then "Bad Gateway"
    when 503 then "Service Unavailable"
    when 504 then "Gateway Timeout"
    when 505 then "HTTP Version Not Supported"
    when 506 then "Variant Also Negotiates"
    when 507 then "Insufficient Storage"
    when 508 then "Loop Detected"
    when 510 then "Not Extended"
    when 511 then "Network Authentication Required"
    else          nil
    end
  end
end
