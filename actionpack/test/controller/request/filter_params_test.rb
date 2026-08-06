require 'abstract_unit'
require 'stringio'

class FilterParamsIntegrationTest < ActionController::IntegrationTest
  class TestController < ActionController::Base
    class_attribute :io

    filter_parameter_logging :password

    def initialize(*)
      io = StringIO.new
      self.logger = Logger.new(io)
      self.class.io = io
      super
    end

    def test
      head :ok
    end
  end

  def teardown
    TestController.io = nil
  end

  def test_filter_parameters_logger
    with_routing do |set|
      set.draw do |map|
        map.connect ':action', :controller => "filter_params_integration_test/test"
      end

      get "/test", 'password=123'
      assert_response :ok

      assert_match Regexp.new(Regexp.escape(inspected_pair('password', '[FILTERED]'))), TestController.io.string
    end
  end
end
