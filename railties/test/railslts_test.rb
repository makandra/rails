require 'abstract_unit'
require 'generators/generator_test_helper'
require 'open3'

class RailsLtsTest < GeneratorTestCase
  REPO_BASE = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

  def setup
    Rails::Generator::Base.use_application_sources!
    run_generator('app', [RAILS_ROOT])
  end

  def with_clean_env(&block)
    if Bundler.respond_to?(:with_unbundled_env)
      Bundler.with_unbundled_env(&block)
    else
      Bundler.with_clean_env(&block)
    end
  end

  def setup_lts(extra_gems = [])
    File.open("#{RAILS_ROOT}/Gemfile", 'w') do |f|
      f.puts <<-GEMFILE
source 'http://rubygems.org'

path '#{REPO_BASE}' do
  gem 'rails',            :require => false
  gem 'actionmailer',     :require => false
  gem 'actionpack',       :require => false
  gem 'activerecord',     :require => false
  gem 'activeresource',   :require => false
  gem 'activesupport',    :require => false
  gem 'railties',         :require => false
  gem 'rack',             :require => false

  #{extra_gems.map { |g| "gem '#{g}', :require => false" }.join("\n")}
end

if RUBY_VERSION >= '3'
  gem 'ruby3-backward-compatibility'
  gem 'i18n'
  gem 'racc'
end

# Stdlib that turned into bundled gems, which a booting Rails 2.3 app has to
# ask for. Requiring one anyway was a warning until Ruby 4.0 made it a
# LoadError, which is why this only guards the newest Ruby. Mirrors the
# RUBY_VERSION >= '3.3' and >= '4' blocks in Gemfile.common.
if RUBY_VERSION >= '4'
  gem 'base64'
  gem 'benchmark'
  gem 'bigdecimal'
  gem 'cgi'
  gem 'csv'
  gem 'drb'
  gem 'logger'
  gem 'mutex_m'
  gem 'nkf'
  gem 'observer'
  gem 'ostruct'
end
      GEMFILE
    end
  end

  def add_config(config)
    current_config = File.read("#{RAILS_ROOT}/config/environment.rb")
    File.open("#{RAILS_ROOT}/config/environment.rb", 'w') do |f|
      f.puts current_config.gsub(/^(end)/, "  #{config}\n\\1")
    end
  end

  def capture3(command)
    if Open3.respond_to?(:capture3)
      Open3.capture3(command)
    else
      stdin, stdout, stderr = Open3.popen3(command)
      stdin.close
      [stdout.read, stderr.read, $?] # last param seems to not work properly, I don't know how to get the exitcode of the command in Ruby 1.8
    end
  end

  def teardown
    super
    Dir["#{RAILS_ROOT}/*"].each do |file|
      rm_rf file
    end
  end

  def test_unconfigured_rails_lts
    setup_lts
    with_clean_env do
      Dir.chdir(RAILS_ROOT) do
        `bundle install`
        stdout, stderr, status = capture3('bundle exec script/runner "puts RailsLts::VERSION::STRING"')
        raise "command failed: #{stderr}" unless status.success?
        assert_match /^2\.3\.18\.\d+$/, stdout
        assert_match /Please configure your rails_lts_options using config.rails_lts_options/, stderr
        assert_match /See https:\/\/makandracards\.com/, stderr
      end
    end
  end

  def test_configured_rails_lts
    setup_lts
    add_config("config.rails_lts_options = { :default => :hardened }")
    with_clean_env do
      Dir.chdir(RAILS_ROOT) do
        `bundle install`
        stdout, stderr, status = capture3('bundle exec script/runner "puts RailsLts::VERSION::STRING"')
        raise "command failed: #{stderr}" unless status.success?
        assert_match /^2\.3\.18\.\d+$/, stdout
      end
    end
  end

  def test_rails_lts_with_deprecated_rails_lts_version
    setup_lts(['railslts-version'])
    with_clean_env do
      Dir.chdir(RAILS_ROOT) do
        `bundle install`
        stdout, stderr, status = capture3('bundle exec script/runner "require \'railslts-version\'"')
        raise "command failed: #{stderr}" unless status.success?
        assert_match /You no longer need the railslts-version gem\. Feel free to remove it from your Gemfile\./, stderr
      end
    end
  end
end
