require 'rack/file'

module Rack

  # = Sendfile
  #
  # The Sendfile middleware intercepts responses whose body is being
  # served from a file and replaces it with a server specific X-Sendfile
  # header. The web server is then responsible for writing the file contents
  # to the client. This can dramatically reduce the amount of work required
  # by the Ruby backend and takes advantage of the web server's optimized file
  # delivery code.
  #
  # In order to take advantage of this middleware, the response body must
  # respond to +to_path+ and the request must include an X-Sendfile-Type
  # header. Rack::File and other components implement +to_path+ so there's
  # rarely anything you need to do in your application. The X-Sendfile-Type
  # header is typically set in your web servers configuration. The following
  # sections attempt to document
  #
  # === Nginx
  #
  # Nginx supports the X-Accel-Redirect header. This is similar to X-Sendfile
  # but requires parts of the filesystem to be mapped into a private URL
  # hierarachy.
  #
  # The following example shows the Nginx configuration required to create
  # a private "/files/" area, enable X-Accel-Redirect, and pass the special
  # X-Sendfile-Type and X-Accel-Mapping headers to the backend:
  #
  #   location ~ /files/(.*) {
  #     internal;
  #     alias /var/www/$1;
  #   }
  #
  #   location / {
  #     proxy_redirect     off;
  #
  #     proxy_set_header   Host                $host;
  #     proxy_set_header   X-Real-IP           $remote_addr;
  #     proxy_set_header   X-Forwarded-For     $proxy_add_x_forwarded_for;
  #
  #     proxy_set_header   X-Accel-Mapping     /var/www/=/files/;
  #
  #     proxy_pass         http://127.0.0.1:8080/;
  #   }
  #
  # The X-Accel-Mapping header should specify the location on the file system,
  # followed by an equals sign (=), followed name of the private URL pattern
  # that it maps to. The middleware performs a simple substitution on the
  # resulting path.
  #
  #  # To enable X-Accel-Redirect, you must configure the middleware explicitly:
  #
  #   use Rack::Sendfile, "X-Accel-Redirect"
  #
  # For security reasons, "X-Accel-Redirect" may not be set via the X-Sendfile-Type header.
  # The sendfile variation must be set via the middleware constructor.
  #
  # See Also: http://wiki.codemongers.com/NginxXSendfile
  #
  # === lighttpd
  #
  # Lighttpd has supported some variation of the X-Sendfile header for some
  # time, although only recent version support X-Sendfile in a reverse proxy
  # configuration.
  #
  #   $HTTP["host"] == "example.com" {
  #      proxy-core.protocol = "http"
  #      proxy-core.balancer = "round-robin"
  #      proxy-core.backends = (
  #        "127.0.0.1:8000",
  #        "127.0.0.1:8001",
  #        ...
  #      )
  #
  #      proxy-core.allow-x-sendfile = "enable"
  #      proxy-core.rewrite-request = (
  #        "X-Sendfile-Type" => (".*" => "X-Sendfile")
  #      )
  #    }
  #
  # See Also: http://redmine.lighttpd.net/wiki/lighttpd/Docs:ModProxyCore
  #
  # === Apache
  #
  # X-Sendfile is supported under Apache 2.x using a separate module:
  #
  # https://tn123.org/mod_xsendfile/
  #
  # Once the module is compiled and installed, you can enable it using
  # XSendFile config directive:
  #
  #   RequestHeader Set X-Sendfile-Type X-Sendfile
  #   ProxyPassReverse / http://localhost:8001/
  #   XSendFile on
  #
  # === Mapping parameter
  #
  # The third parameter allows for an overriding extension of the
  # X-Accel-Mapping header. Mappings should be provided in tuples of internal to
  # external. The internal values may contain regular expression syntax, they
  # will be matched with case indifference.
  #
  # When X-Accel-Redirect is explicitly enabled via the variation parameter,
  # and no application-level mappings are provided, the middleware will read
  # the X-Accel-Mapping header from the proxy. This allows nginx to control
  # the path mapping without requiring application-level configuration.
  #
  # === Security
  #
  # For security reasons, the X-Sendfile-Type header from HTTP requests may only
  # be set to "X-Sendfile" or "X-Lighttpd-Send-File". Other values such as
  # "X-Accel-Redirect" are not permitted to prevent information disclosure
  # vulnerabilities where attackers could bypass proxy restrictions.


  class Sendfile
    F = ::File
    SAFE_SENDFILE_VARIATIONS = ['X-Sendfile', 'X-Lighttpd-Send-File']

    def initialize(app, variation=nil)
      @app = app
      @variation = variation
    end

    def call(env)
      status, headers, body = @app.call(env)
      if body.respond_to?(:to_path)
        case type = variation(env)
        when 'X-Accel-Redirect'
          path = F.expand_path(body.to_path)
          if url = map_accel_path(env, path)
            headers['Content-Length'] = '0'
            headers[type] = url
            body = []
          else
            env['rack.errors'].puts "X-Accel-Mapping header missing"
          end
        when 'X-Sendfile', 'X-Lighttpd-Send-File'
          path = F.expand_path(body.to_path)
          headers['Content-Length'] = '0'
          headers[type] = path
          body = []
        when '', nil
        else
          env['rack.errors'].puts "Unknown x-sendfile variation: #{type.inspect}"
        end
      end
      [status, headers, body]
    end

    private

    def x_sendfile_type(env)
      sendfile_type = env['HTTP_X_SENDFILE_TYPE']
      if SAFE_SENDFILE_VARIATIONS.include?(sendfile_type)
        sendfile_type
      else
        env['rack.errors'].puts "Unknown or unsafe x-sendfile variation: #{sendfile_type.inspect}"
      end
    end

    def variation(env)
      @variation ||
        env['sendfile.type'] ||
        x_sendfile_type(env)
    end

    def x_accel_mapping(env)
      # Only allow header when:
      # 1. X-Accel-Redirect is explicitly enabled via constructor.
      # 2. No application-level mappings are configured.
      return nil unless @variation == 'X-Accel-Redirect'

      env['HTTP_X_ACCEL_MAPPING']
    end

    def map_accel_path(env, path)
      if mapping = x_accel_mapping(env)
        # Safe to use header: explicit config + no app mappings
        internal, external = mapping.split('=', 2).map{ |p| p.strip }
        path.sub(/\A#{internal}/i, external)
      end
    end

  end
end
