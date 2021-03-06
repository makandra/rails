if RUBY_VERSION >= '2'
  # we no longer support this
  exit(0)
end

def with_clean_env
  # does not seem to work any more, so just ignore
  yield
end

with_clean_env do
  require 'plugin_test_helper'

  class Rails::GemDependency
    public :install_command, :unpack_command
  end

  Rails::VendorGemSourceIndex.silence_spec_warnings = true

  class GemDependencyTest < Test::Unit::TestCase
    def setup
      @gem              = Rails::GemDependency.new "xhpricotx"
      @gem_with_source  = Rails::GemDependency.new "xhpricotx", :source => "http://code.whytheluckystiff.net"
      @gem_with_version = Rails::GemDependency.new "xhpricotx", :version => "= 0.6"
      @gem_with_lib     = Rails::GemDependency.new "xaws-s3x", :lib => "aws/s3"
      @gem_without_load  = Rails::GemDependency.new "xhpricotx", :lib => false
    end

    def not_with_bundler
      if defined?(Bundler)
        puts "Skipping test, does not work when bundled"
      else
        yield
      end
    end

    def test_configuration_adds_gem_dependency
      config = Rails::Configuration.new
      config.gem "xaws-s3x", :lib => "aws/s3", :version => "0.4.0"
      assert_equal [["install", "xaws-s3x", "--version", '"= 0.4.0"']], config.gems.collect { |g| g.install_command }
    end

    def test_gem_creates_install_command
      assert_equal ["install", "xhpricotx", "--version", '">= 0"'], @gem.install_command
    end

    def test_gem_with_source_creates_install_command
      assert_equal ["install", "xhpricotx", "--version", '">= 0"', "--source", "http://code.whytheluckystiff.net"], @gem_with_source.install_command
    end

    def test_gem_with_version_creates_install_command
      assert_equal ["install", "xhpricotx", "--version", '"= 0.6"'], @gem_with_version.install_command
    end

    def test_gem_creates_unpack_command
      mock_spec = mock()
      mock_spec.stubs(:version).returns('0.6')
      @gem.stubs(:specification).returns(mock_spec)
      assert_equal ["unpack", "xhpricotx", "--version", '= 0.6'], @gem.unpack_command
    end

    def test_gem_with_version_unpack_install_command
      # stub out specification method, or else test will fail if hpricot 0.6 isn't installed
      mock_spec = mock()
      mock_spec.stubs(:version).returns('0.6')
      @gem_with_version.stubs(:specification).returns(mock_spec)
      assert_equal ["unpack", "xhpricotx", "--version", '= 0.6'], @gem_with_version.unpack_command
    end

    def test_gem_adds_load_paths
      @gem.expects(:gem).with(@gem.name, @gem.requirement)
      @gem.add_load_paths
    end

    def test_gem_with_version_adds_load_paths
      @gem_with_version.expects(:gem).with(@gem_with_version.name, @gem_with_version.requirement)
      @gem_with_version.add_load_paths
      assert @gem_with_version.load_paths_added?
    end

    def test_gem_loading
      @gem.expects(:gem).with(@gem.name, @gem.requirement)
      @gem.expects(:require).with(@gem.name)
      @gem.add_load_paths
      @gem.load
      assert @gem.loaded?
    end

    def test_gem_with_lib_loading
      @gem_with_lib.expects(:gem).with(@gem_with_lib.name, @gem_with_lib.requirement)
      @gem_with_lib.expects(:require).with(@gem_with_lib.lib)
      @gem_with_lib.add_load_paths
      @gem_with_lib.load
      assert @gem_with_lib.loaded?
    end

    def test_gem_without_lib_loading
      @gem_without_load.expects(:gem).with(@gem_without_load.name, @gem_without_load.requirement)
      @gem_without_load.expects(:require).with(@gem_without_load.lib).never
      @gem_without_load.add_load_paths
      @gem_without_load.load
    end

    def test_gem_load_frozen
      not_with_bundler do
        dummy_gem = Rails::GemDependency.new "dummy-gem-a"
        dummy_gem.add_load_paths
        dummy_gem.load
        assert_not_nil DUMMY_GEM_A_VERSION
      end
    end

    def test_gem_load_frozen_specific_version
      not_with_bundler do
        dummy_gem = Rails::GemDependency.new "dummy-gem-b", :version => '0.4.0'
        dummy_gem.add_load_paths
        dummy_gem.load
        assert_not_nil DUMMY_GEM_B_VERSION
        assert_equal '0.4.0', DUMMY_GEM_B_VERSION
      end
    end

    def test_gem_load_frozen_minimum_version
      not_with_bundler do
        dummy_gem = Rails::GemDependency.new "dummy-gem-c", :version => '>=0.5.0'
        dummy_gem.add_load_paths
        dummy_gem.load
        assert_not_nil DUMMY_GEM_C_VERSION
        assert_equal '0.6.0', DUMMY_GEM_C_VERSION
      end
    end
    
    def test_gem_load_frozen_when_platform_string_is_present    
      not_with_bundler do
        dummy_gem = Rails::GemDependency.new "dummy-gem-l"
        dummy_gem.add_load_paths
        dummy_gem.load
        assert_not_nil DUMMY_GEM_L_VERSION
        assert_equal "1.0.0", DUMMY_GEM_L_VERSION
      end
    end

    def test_gem_load_missing_specification
      not_with_bundler do
        dummy_gem = Rails::GemDependency.new "dummy-gem-d"
        dummy_gem.add_load_paths
        dummy_gem.load
        assert_not_nil DUMMY_GEM_D_VERSION
        assert_equal '1.0.0', DUMMY_GEM_D_VERSION
        assert_equal ['lib', 'lib/dummy-gem-d.rb'], dummy_gem.specification.files
      end
    end

    def test_gem_load_bad_specification
      not_with_bundler do
        dummy_gem = Rails::GemDependency.new "dummy-gem-e", :version => "= 1.0.0"
        dummy_gem.add_load_paths
        dummy_gem.load
        assert_not_nil DUMMY_GEM_E_VERSION
        assert_equal '1.0.0', DUMMY_GEM_E_VERSION
      end
    end

    def test_gem_handle_missing_dependencies
      not_with_bundler do
        dummy_gem = Rails::GemDependency.new "dummy-gem-g"
        dummy_gem.add_load_paths
        dummy_gem.load
        assert_equal 1, dummy_gem.dependencies.size
        assert_equal 1, dummy_gem.dependencies.first.dependencies.size
        assert_nothing_raised do
          dummy_gem.dependencies.each do |g|
            g.dependencies
          end
        end
      end
    end

    def test_gem_ignores_development_dependencies
      not_with_bundler do
        dummy_gem = Rails::GemDependency.new "dummy-gem-k"
        dummy_gem.add_load_paths
        dummy_gem.load
        assert_equal 1, dummy_gem.dependencies.size
      end
    end

    def test_gem_guards_against_duplicate_unpacks
      dummy_gem = Rails::GemDependency.new "dummy-gem-a"
      dummy_gem.stubs(:frozen?).returns(true)
      dummy_gem.expects(:unpack_base).never
      dummy_gem.unpack
    end

    def test_gem_does_not_unpack_framework_gems
      dummy_gem = Rails::GemDependency.new "dummy-gem-a"
      dummy_gem.stubs(:framework_gem?).returns(true)
      dummy_gem.expects(:unpack_base).never
      dummy_gem.unpack
    end

    def test_gem_from_directory_name_attempts_to_load_specification
      assert_raises RuntimeError do
        dummy_gem = Rails::GemDependency.from_directory_name('dummy-gem-1.1')
      end
    end

    def test_gem_from_directory_name
      dummy_gem = Rails::GemDependency.from_directory_name('dummy-gem-1.1', false)
      assert_equal 'dummy-gem', dummy_gem.name
      assert_equal '= 1.1',     dummy_gem.requirement.to_s
    end

    def test_gem_from_directory_name_loads_specification_successfully
      assert_nothing_raised do
        dummy_gem = Rails::GemDependency.from_directory_name(File.join(Rails::GemDependency.unpacked_path, 'dummy-gem-g-1.0.0'))
        assert_not_nil dummy_gem.specification
      end
    end

    def test_gem_from_invalid_directory_name
      assert_raises RuntimeError do
        dummy_gem = Rails::GemDependency.from_directory_name('dummy-gem')
      end
      assert_raises RuntimeError do
        dummy_gem = Rails::GemDependency.from_directory_name('dummy')
      end
    end

    def test_gem_determines_build_status_only_on_vendor_gems
      framework_gem = Rails::GemDependency.new('dummy-framework-gem')
      framework_gem.stubs(:framework_gem?).returns(true)  # already loaded
      framework_gem.stubs(:vendor_rails?).returns(false)  # but not in vendor/rails
      framework_gem.stubs(:vendor_gem?).returns(false)  # and not in vendor/gems
      framework_gem.add_load_paths  # freeze framework gem early 
      assert framework_gem.built?
    end

    def test_gem_build_passes_options_to_dependencies
      mock_spec = mock()
      mock_spec.stubs(:full_name).returns('Dummy Gem G')
      mock_spec.stubs(:version).returns('0.6')
      start_gem = Rails::GemDependency.new("dummy-gem-g")
      dep_gem = Rails::GemDependency.new("dummy-gem-f")
      start_gem.stubs(:dependencies).returns([dep_gem])
      start_gem.stubs(:specification).returns(mock_spec)
      start_gem.stubs(:built?).returns(true)
      dep_gem.expects(:build).with({ :force => false }).once
      start_gem.build(:force => false)
    end

  end
end
