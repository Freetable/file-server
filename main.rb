#!/usr/bin/env ruby

require 'rubygems'  
require 'mongo'
require 'sinatra'
require 'sinatra/streaming'
require 'connection_pool'
require 'openssl'

set :bind, '0.0.0.0'

include Mongo
helpers Sinatra::Streaming

@@grid_pool = ConnectionPool.new( :size => 4 ) { GridFileSystem.new(MongoClient.new("localhost", 27017).db('Freetable')) }

get '/get/:filename' do
  # 60 * 60 = 3600 seconds * minutes = result
	cache_control :public, :max_age => 3600
  exists = true
  output = ''
	@@grid_pool.with do |grid_handle|
#		begin
			logger.info "Opening #{params[:filename]}"
			grid_handle.open(params[:filename],"r") { |f| output = output + f.read }
#		rescue => e
#			exists = false
#		end
	end
  if exists 
  	etag OpenSSL::Digest::MD5.hexdigest(output)
    response.headers['Content-Type'] = 'audio/mpeg'
  	return output
	else
  	return "-1"
	end
end

get '/test/:filename' do
  # one day
  cache_control :public, :max_age => 86400 
  @@grid_pool.with do |grid_handle|
  	begin
  		grid_handle.open(params[:filename],"r") { |f| (output = output + f.read) }
  	rescue => e
			return 0
  	end
	end
  etag OpenSSL::Digest::MD5.hexdigest(output)
  return '1' if output.length > 0
	return '0'
end

#get '/add/:auth/:filename' do
post '/add' do
	unless params[:file] && (tmpfile = params[:file][:tempfile]) && (name = params[:file][:filename])
		return "-1"
	end
	
	while blk = tmpfile.read(65536)
   (file = file + blk)
  end

	# Create wwuid

  wwfileid = file.md5 #this will come from network services later
  
  @@grid_pool.with do |grid_handle|
    begin
      grid_handle.open(OpenSSL::Digest::MD5.hexdigest(file),"w",{ :metadata => { 
																																		:md5 => OpenSSL::Digest::MD5.hexdigest(file), 
																																		:sha1 => OpenSSL::Digest::SHA1.hexdigest(file), 
																																		:sha512 => OpenSSL::Digest::SHA512.hexdigest(file) 
																																	} 
																																	}) { |f| f.write(file) }
    rescue => e
      return "0"
    end
  end
return "1"
end

