# A support class that provides additional around HTTP status codes.
#
# Based on [Hypertext Transfer Protocol (HTTP) Status Code Registry](https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml)
#
# It provides constants for the defined HTTP status codes as well as helper
# methods to easily identify the type of response.
enum HTTP::StatusCode
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

  # Returns `true` if the response status code is between 100 and 199.
  def self.informational?(status_code : Int)
    100 <= status_code <= 199
  end

  # Returns `true` if the response status code is between 200 and 299.
  def self.success?(status_code : Int)
    200 <= status_code <= 299
  end

  # Returns `true` if the response status code is between 300 and 399.
  def self.redirection?(status_code : Int)
    300 <= status_code <= 399
  end

  # Returns `true` if the response status code is between 400 and 499.
  def self.client_error?(status_code : Int)
    400 <= status_code <= 499
  end

  # Returns `true` if the response status code is between 500 and 599.
  def self.server_error?(status_code : Int)
    500 <= status_code <= 599
  end

  # Returns the default status message of the given HTTP status code.
  def default_message : String
    case value
    when 200 then "OK"
    when 203 then "Non-Authoritative Information"
    when 207 then "Multi-Status"
    when 226 then "IM Used"
    when 414 then "URI Too Long"
    when 418 then "I'm a teapot"
    else
      to_s.split("_").map do |keyword|
        keyword.capitalize
      end.join(" ")
    end
  end
end
