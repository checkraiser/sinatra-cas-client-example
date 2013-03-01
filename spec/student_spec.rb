
require 'rspec'
require 'rack/test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

#set :environment, :test
require_relative '../lib/userservice_test'


describe 'The Account App' do
  include Rack::Test::Methods
   before { @us = UserService.new  }
 
  it "get student profile" do   
    v = @us.getprofile('061C660022')
    v.should_not be_nil
    if v then
      puts v.inspect
    end
  end
end