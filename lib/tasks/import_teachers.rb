require 'csv'
#require_relative '../models_test'
require_relative '../models'
require 'data_mapper'


CSV.foreach("D:/emails.csv") do |row|
    # use row here...
    str = row[0].to_str.strip
    teacher = Teacher.new(:email => str)
    if teacher.save then puts "OK" else puts "error " + str end
end