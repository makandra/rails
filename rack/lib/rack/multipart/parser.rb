require 'rack/utils'

module Rack
  module Multipart
    class MultipartLimitError < Errno::EMFILE; end
    class MultipartTotalPartLimitError < StandardError; end

    class Parser
      BUFSIZE = 16384
      MIME_HEADER_BYTESIZE_LIMIT = 64 * 1024

      def initialize(env)
        @env = env
      end

      def parse
        return nil unless setup_parse

        fast_forward_to_first_boundary

        opened_files = 0
        parts = 0
        loop do
          head, filename, content_type, name, body =
            get_current_head_and_filename_and_content_type_and_name_and_body

          if Utils.multipart_part_limit > 0
            opened_files += 1 if filename
            if opened_files >= Utils.multipart_part_limit
              close_tempfiles
              raise MultipartLimitError, 'Maximum file multiparts in content reached'
            end
          end

          if Utils.multipart_total_part_limit > 0
            parts += 1
            if parts >= Utils.multipart_total_part_limit
              close_tempfiles
              raise MultipartTotalPartLimitError, 'Maximum total multiparts in content reached'
            end
          end

          # Save the rest.
          if i = @buf.index(rx)
            body << @buf.slice!(0, i)
            update_retained_size(i) unless filename
            @buf.slice!(0, @boundary_size+2)

            @content_length = -1  if $1 == "--"
          end

          filename, data = get_data(filename, body, content_type, name, head)

          Utils.normalize_params(@params, name, data) unless data.nil?

          # break if we're at the end of a buffer, but not if it is the end of a field
          break if (@buf.empty? && $1 != EOL) || @content_length == -1
        end

        @io.rewind

        @params.to_params_hash
      end

      private
      def setup_parse
        match = MULTIPART.match(@env['CONTENT_TYPE'])
        return false unless match

        unless match[1].empty?
          raise EOFError, "whitespace between boundary parameter name and equal sign"
        end
        if match.post_match =~ /boundary\s*=/i
          raise EOFError, "multiple boundary parameters found in multipart content type"
        end

        @boundary = "--#{match[2]}"

        @buf = ""
        @params = Utils::KeySpaceConstrainedParams.new

        @io = @env['rack.input']
        @io.rewind

        @boundary_size = Utils.bytesize(@boundary) + EOL.size

        if @content_length = @env['CONTENT_LENGTH']
          @content_length = @content_length.to_i
          @content_length -= @boundary_size
        end

        if Utils.multipart_parser_bytesize_limit > 0 && @content_length && @content_length > Utils.multipart_parser_bytesize_limit
          raise EOFError, "multipart Content-Length #{@content_length} exceeds limit of #{Utils.multipart_parser_bytesize_limit} bytes"
        end

        @retained_size = 0
        @total_bytes_read = Utils.multipart_parser_bytesize_limit > 0 ? 0 : nil
        true
      end

      def full_boundary
        @boundary + EOL
      end

      def rx
        @rx ||= /(?:#{EOL})?#{Regexp.quote(@boundary)}(#{EOL}|--)/n
      end

      def fast_forward_to_first_boundary
        loop do
          content = @io.read(BUFSIZE)
          raise EOFError, "bad content body" unless content
          check_bytes_read(content)
          @buf << content

          while @buf.gsub!(/\A([^\n]*\n)/, '')
            read_buffer = $1
            return if read_buffer == full_boundary
          end

          raise EOFError, "multipart boundary not found within limit" if Utils.bytesize(@buf) >= BUFSIZE
        end
      end

      def get_current_head_and_filename_and_content_type_and_name_and_body
        head = nil
        body = ''
        filename = content_type = name = nil
        content = nil

        until head && @buf =~ rx
          if !head && i = @buf.index(EOL+EOL)
            head = @buf.slice!(0, i+2) # First \r\n

            @buf.slice!(0, 2)          # Second \r\n

            update_retained_size(head.bytesize)
            content_type = head[MULTIPART_CONTENT_TYPE, 1]
            name = get_name(head)

            filename = get_filename(head)

            if filename
              body = Tempfile.new("RackMultipart")
              (@env['rack.tempfiles'] ||= []) << body
              body.binmode  if body.respond_to?(:binmode)
            end

            next
          end

          # Save the read body part.
          size_to_read = @buf.size - (@boundary_size+4)
          if head && size_to_read > 0
            body << @buf.slice!(0, size_to_read)
            update_retained_size(size_to_read) unless filename
          end

          content = @io.read(@content_length && BUFSIZE >= @content_length ? @content_length : BUFSIZE)
          raise EOFError, "bad content body"  if content.nil? || content.empty?
          check_bytes_read(content)

          @buf << content

          raise EOFError, "multipart mime part header too large" if @buf.size > MIME_HEADER_BYTESIZE_LIMIT

          @content_length -= content.size if @content_length
        end

        [head, filename, content_type, name, body]
      end

      def get_name(head)
        name = if (disposition_value = head[MULTIPART_CONTENT_DISPOSITION, 1])
          disposition_value[MULTIPART_CONTENT_DISPOSITION_NAME, 1]
        end
        name || head[MULTIPART_CONTENT_ID, 1]
      end

      def get_filename(head)
        filename = nil
        if head =~ RFC2183
          filename = Hash[head.scan(DISPPARM)]['filename']
          filename = $1 if filename and filename =~ /^"(.*)"$/
        elsif head =~ BROKEN
          filename = $1
          filename = $1 if filename =~ /^"(.*)"$/
        end

        if filename && filename.scan(/%.?.?/).all? { |s| s =~ /%[0-9a-fA-F]{2}/ }
          filename = Utils.unescape(filename)
        end
        if filename && filename !~ /\\[^\\"]/
          filename = filename.gsub(/\\(.)/, '\1')
        end
        filename
      end

      def close_tempfiles
        (@env['rack.tempfiles'] || []).each(&:close!)
      end

      def get_data(filename, body, content_type, name, head)
        data = nil
        if filename == ""
          # filename is blank which means no file has been selected
          return data
        elsif filename
          body.rewind

          # Take the basename of the upload's original filename.
          # This handles the full Windows paths given by Internet Explorer
          # (and perhaps other broken user agents) without affecting
          # those which give the lone filename.
          filename = filename.split(/[\/\\]/).last

          data = {:filename => filename, :type => content_type,
                  :name => name, :tempfile => body, :head => head}
        elsif !filename && content_type && body.is_a?(IO)
          body.rewind

          # Generic multipart cases, not coming from a form
          data = {:type => content_type,
                  :name => name, :tempfile => body, :head => head}
        else
          data = body
        end

        [filename, data]
      end

      def check_bytes_read(content)
        return unless @total_bytes_read
        @total_bytes_read += content.bytesize
        if @total_bytes_read > Utils.multipart_parser_bytesize_limit
          raise EOFError, "multipart upload exceeds limit of #{Utils.multipart_parser_bytesize_limit} bytes"
        end
      end

      def update_retained_size(size)
        @retained_size += size
        if @retained_size > Utils.buffered_upload_bytesize_limit
          raise EOFError, "multipart data over retained size limit"
        end
      end
    end
  end
end
