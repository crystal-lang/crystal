module MIME::Multipart
  private enum State
    START
    PREAMBLE
    BODY_PART
    EPILOGUE
    FINISHED
    ERRORED
  end
end
