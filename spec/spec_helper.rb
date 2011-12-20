require 'simplecov'
SimpleCov.start
require File.expand_path("../../lib/dada.rb", __FILE__)
require 'helpers/active_model_lint'

require 'dummy/dummy_rest_client'
require 'dummy/configure'
require 'dummy/child'
require 'dummy/dummy'

require 'fakeweb'
require 'helpers/fakeweb_responses'
require 'json'

#Fakeweb to stub server responses, still want to to integration tests on the rest client
def build(object)
  {
    :dummy => lambda { Dummy.new({:title => 'Dummy', :description => 'Crash me!', :id => Dummy.children.length + 1})},
    :child => lambda { Child.new({:title => 'Child', :description => 'Daddy!', :id => Child.children.length + 1}) }
  }[object].call
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.after(:each) { Dada::Config.memcached_instance.flush }
  config.before(:each) { Dummy.resource_suffix = '' }
end

