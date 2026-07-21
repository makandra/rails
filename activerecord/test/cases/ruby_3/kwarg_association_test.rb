require "cases/helper"
require 'models/topic'
require 'models/reply' # test fails without reply because of STI stuff

class KwargAssociationTest < ActiveRecord::TestCase
  fixtures :topics

  # Calling a class method (or named_scope) with keyword arguments through a
  # has_many association routes through AssociationCollection#method_missing,
  # which forwards *args to the target class. On ruby >= 3.0 that method_missing
  # must be ruby2_keywords-flagged, otherwise the trailing kwargs hash is passed
  # along as a positional argument and the target raises ArgumentError.
  def test_class_methods_with_keyword_args_can_be_called_on_associations
    assert_equal [topics(:second).id],
      topics(:first).replies.for_author(author_name: 'Mary').map(&:id)
  end
end
