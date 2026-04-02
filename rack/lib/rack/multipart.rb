module Rack
  # A multipart form data parser, adapted from IOWA.
  #
  # Usually, Rack::Request#POST takes care of calling this.
  module Multipart
    autoload :UploadedFile, 'rack/multipart/uploaded_file'
    autoload :Parser, 'rack/multipart/parser'
    autoload :Generator, 'rack/multipart/generator'

    EOL = "\r\n"
    FWS = /[ \t]+(?:\r\n[ \t]+)?/ # whitespace with optional folding
    HEADER_VALUE = "(?:[^\r\n]|\r\n[ \t])*" # anything but a non-folding CRLF
    MULTIPART_BOUNDARY = "AaB03x"
    MULTIPART = %r|\Amultipart/.*?boundary(\s*)=\"?([^\";,]+)\"?|ni
    TOKEN = /[^\s()<>,;:\\"\/\[\]?=]+/
    CONDISP = /Content-Disposition:\s*#{TOKEN}\s*/i
    DISPPARM = /;\s*(#{TOKEN})=("(?:\\"|[^"])*"|#{TOKEN})/
    RFC2183 = /^#{CONDISP}(#{DISPPARM})+$/i
    VALUE = /"(?:\\"|[^"])*"|#{TOKEN}/
    BROKEN = /^#{CONDISP}.*;\s*filename=(#{VALUE})/i

    MULTIPART_CONTENT_TYPE = /^Content-Type:#{FWS}?(#{HEADER_VALUE})/ni
    MULTIPART_CONTENT_DISPOSITION = /^Content-Disposition:#{FWS}?(#{HEADER_VALUE})/ni
    MULTIPART_CONTENT_ID = /^Content-ID:#{FWS}?(#{HEADER_VALUE})/ni

    MULTIPART_CONTENT_DISPOSITION_NAME = /;\s+name="?([^\";]*)"?/ni

    class << self
      def parse_multipart(env)
        Parser.new(env).parse
      end

      def build_multipart(params, first = true)
        Generator.new(params, first).dump
      end
    end

  end
end
