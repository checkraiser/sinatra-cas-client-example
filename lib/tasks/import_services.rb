# encoding: utf-8
require 'savon'
require 'data_mapper'
require 'date'
require 'time'

require_relative '../models_test'
#DataMapper.auto_migrate!
def runit()
	svs = [{:name => 'Diễn đàn sinh viên',
			:url => 'http://diendan.hpu.edu.vn'},
			{:name => 'Thư viện ảnh HPU',
			:url => 'http://image.hpu.edu.vn'}]

 	role = Role.first(:name => 'Guest')
 	svs.each do |sv|
 		msv = Service.first_or_create(:name => sv[:name], :url => sv[:url])
 		msv.roles << role
 		begin
 			msv.save and role.save
	 	rescue
	 		puts "error save"
	 	end
	 	puts "save #{sv[:url]} ok"
 	end
end

runit()




