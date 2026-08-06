require File.expand_path('../../../test_warnings', __FILE__)
$:.unshift File.expand_path('../../lib', __FILE__)
$:.unshift File.expand_path('../../../activesupport/lib', __FILE__)
$:.unshift File.expand_path('../fixtures/helpers', __FILE__)
$:.unshift File.expand_path('../fixtures/alternate_helpers', __FILE__)
$:.unshift File.expand_path('../../../railties/lib', __FILE__)
$:.unshift File.expand_path('../../../rack/lib', __FILE__)

require 'rubygems'
require 'yaml'
require 'stringio'
require 'test/unit'

gem 'mocha', '>= 0.9.7'
require 'mocha'

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end

require 'action_controller'
require 'action_controller/cgi_ext'
require 'action_controller/test_process'
require 'action_view/test_case'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

ActionController::Base.logger = nil
ActionController::Routing::Routes.reload rescue nil

ActionController::Base.session_store = nil

# Register languages for testing
I18n.backend.store_translations 'da', "da" => {}
I18n.backend.store_translations 'pt-BR', "pt-BR" => {}
ORIGINAL_LOCALES = I18n.available_locales.map(&:to_s).sort

FIXTURE_LOAD_PATH = File.join(File.dirname(__FILE__), 'fixtures')
ActionView::Base.cache_template_loading = true
ActionController::Base.view_paths = FIXTURE_LOAD_PATH
CACHED_VIEW_PATHS = ActionView::Base.cache_template_loading? ?
                      ActionController::Base.view_paths :
                      ActionController::Base.view_paths.map {|path| ActionView::Template::EagerPath.new(path.to_s)}

class DummyMutex
  def lock
    @locked = true
  end

  def unlock
    @locked = false
  end

  def locked?
    @locked
  end
end

class ActionController::IntegrationTest < ActiveSupport::TestCase
  def with_autoload_path(path)
    path = File.join(File.dirname(__FILE__), "fixtures", path)  
    if ActiveSupport::Dependencies.autoload_paths.include?(path)
      yield
    else
      begin
        ActiveSupport::Dependencies.autoload_paths << path
        yield
      ensure
        ActiveSupport::Dependencies.autoload_paths.reject! {|p| p == path}
        ActiveSupport::Dependencies.clear
      end              
    end
  end
end

module RailsXssEmulation
  module ContentTag
    def self.included(by)
      by.alias_method_chain :content_tag_string, :escaping
    end

    private

    def content_tag_string_with_escaping(name, content, options, escape = true)
      content_tag_string_without_escaping(name, escape ? ERB::Util.h(content) : content, options, escape)
    end

  end

  class InstanceTagWithRailsXss < ActionView::Helpers::InstanceTag
    include RailsXssEmulation::ContentTag
  end

end

ActionController::Reloader.default_lock = DummyMutex.new

Rack::Session::Abstract::ID::DEFAULT_OPTIONS[:sidbits] = 32 # 128 causes a core dump on CI

# Rails LTS: Ruby 3.4 changed how Hash#inspect renders a pair twice over —
# {"a"=>1} gained spaces around the arrow, and {:a=>1} became {a: 1}. Tests that
# assert on an inspected hash ask for the current rendering of one pair rather
# than hardcoding a format that only holds on some Rubies.
def inspected_pair(key, value)
  { key => value }.inspect[1...-1]
end

def pair_pattern(key, value)
  Regexp.new(Regexp.escape(inspected_pair(key, value)))
end
