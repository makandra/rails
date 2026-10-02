require 'cgi'

# Rails LTS: Ruby 4.0 builds in only the escaping half of cgi. The request half
# patched below — CGI::QueryExtension, CGI::Cookie, CGI.rfc1123_date — comes from
# the gem now. Requiring cgi succeeds either way, so there is no LoadError to
# catch and we have to look for the constant.
require 'active_support/rails_lts/bundled_gems'
unless defined?(CGI::QueryExtension)
  fail RailsLts::Support::Ruby::MissingBundledGem, "Ruby #{RUBY_VERSION} only builds in the escaping half of cgi, and Rails needs " \
                  "the rest of it. Please add \"gem 'cgi'\" to your Gemfile."
end

require 'action_controller/cgi_ext/stdinput'
require 'action_controller/cgi_ext/query_extension'
require 'action_controller/cgi_ext/cookie'

class CGI #:nodoc:
  include ActionController::CgiExt::Stdinput

  class << self
    alias :escapeHTML_fail_on_nil :escapeHTML

    def escapeHTML(string)
      # escapeHTML does not escape single quotes on Ruby 1.8.7
      escapeHTML_fail_on_nil(string).gsub("'", '&#39;') unless string.nil?
    end
  end
end
