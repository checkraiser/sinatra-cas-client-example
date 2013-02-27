
require 'rspec'
require 'rack/test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

#set :environment, :test
require_relative '../userservice_test'


describe 'The Account App' do
  include Rack::Test::Methods
   before { @us = UserService.new  }
 
  it "register new guest" do
  	bg = Digest::MD5.hexdigest('123456')
  	v = @us.register_guest('dungth@hpu.edu.vn', Digest::MD5.hexdigest('123456'))
  	if v == 1 then
  		user = @us.get_user('dungth@hpu.edu.vn')
  		user[:password].should == bg
  	end
  end
  it "register new teacher" do
  	t = @us.register_teacher('tuyendv@hpu.edu.vn')
  	if t == 1 then
  		user = @us.get_teacher('tuyendv@hpu.edu.vn')
  		user[:email].should == 'tuyendv@hpu.edu.vn'
  	end
  end
  it "register new student" do
  	sis = '110639'
  	v = @us.register_student(sis)
  	#if v == 1 then
  	v[:code].should = 1
  	user = @us.get_student(sis)
  	user[:email].should == 'minh-110639@sv.hpu.vn'
  	
  end  
  it "activate user" do
  	token = 'e4fd67559ded2d52cbb10ad03f7f80e8'
  	v = @us.confirm_register(token)  	
	  user = @us.get_user('tuyendv@hpu.edu.vn')
	  user[:status].should == 1  
  end
  it "change password" do
  	newpass = '1234567'
  	hash_newpass = Digest::MD5.hexdigest(newpass)
  	email = 'tuyendv@hpu.edu.vn'
  	v = @us.changepassword(email, newpass)
  	v[:code].should == 1
  	user = @us.get_user(email)
  	user[:password].should == hash_newpass
  end
  it "change profile" do
    email = 'tuyendv@hpu.edu.vn'
    xprofile = {:email => 'tuyendv@gmail.com'}
    v = @us.changeprofile(email, xprofile)
    v[:code].should == 1
  end
end