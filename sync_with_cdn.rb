#!/usr/bin/ruby

require 'filespot'
require 'time'
require 'net/http'

Filespot.configure do |config|
  config.apiuserid = 'apiuserid'
  config.apikey = 'apikey'
end

local_list = {}
cdn_list = {}
root_dir = '/home/www/project/htdocs'
data_dir = 'syncdir'

cur_time = Time.now.strftime("%d/%m/%Y %H:%M")
puts "#{cur_time} synchronization started"

Dir.foreach( "#{root_dir}/#{data_dir}" ) do |local_object|
    next if local_object == '.' or local_object == '..'
    cdn_path = "/#{data_dir}/#{local_object}"
    local_path = "#{root_dir}/#{data_dir}/#{local_object}"
    modify_time = File.mtime(local_path)
    local_data = [ local_path , modify_time ]
    local_list.store( cdn_path , local_data )
end

cdn_objects = Filespot::Client.get_objects
cdn_objects.each do |cdn_object|
    upload_time = Time.parse( cdn_object.create_date )
    cdn_data = [ cdn_object.id , upload_time ]
    cdn_list.store( cdn_object.path , cdn_data )
end

upload_list = local_list.clone
cdn_list.each {|key, value| upload_list.delete(key)}
upload_list.each do |cdn_path, cdn_data|
    result = Filespot::Client.post_object( cdn_data[0], cdn_path )
    if result.status.eql?"ok"
        puts "#{cdn_path} uploaded"
    end
end
    
remove_list = cdn_list.clone
local_list.each {|key, value| remove_list.delete(key)}
remove_list.each do |cdn_path, cdn_data|
    result = Filespot::Client.delete_object( cdn_data[0] )
    if result.status.eql?"success"
        puts "#{cdn_path} deleted"
        uri = URI("http://api.cdnvideo.ru:8888/0/delete?id=12345_user&type=http&object=http://origin.platformcraft.ru/project#{cdn_path}")
        res = Net::HTTP.get_response(uri)
        puts res.header if res.is_a?(Net::HTTPSuccess)
    end
end

local_list.each do |cdn_path, cdn_data|
    if cdn_list.include?cdn_path
        if local_list[cdn_path][1] > cdn_list[cdn_path][1]
            result = Filespot::Client.delete_object( cdn_list[cdn_path][0] )
            if result.status.eql?"success"
                puts "#{cdn_path} old version deleted"
                uri = URI("http://api.cdnvideo.ru:8888/0/delete?id=12345_user&type=http&object=http://origin.platformcraft.ru/project#{cdn_path}")
                res = Net::HTTP.get_response(uri)
                puts res.header if res.is_a?(Net::HTTPSuccess)
            end
            result = Filespot::Client.post_object( local_list[cdn_path][0], cdn_path )
            if result.status.eql?"ok"
                puts "#{cdn_path} new version uploaded"
            end
        end
    end
end

cur_time = Time.now.strftime("%d/%m/%Y %H:%M")
puts "#{cur_time} synchronization ended"

