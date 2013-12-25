#!/usr/bin/env ruby

require 'rubygems'  
require 'mongo'
require 'sinatra'
require 'connection_pool'
require 'openssl'
require 'rest_client'
require 'json'

set :bind, '0.0.0.0'

include Mongo

@@grid_pool = ConnectionPool.new( :size => 4 ) { GridFileSystem.new(MongoClient.new("localhost", 27017).db('Freetable')) }

get '/get/:filename.mid' do
  # 60 * 60 = 3600 seconds * minutes = result = 1 hr
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
    response.headers['Content-Type'] = 'audio/mpeg'
		etag OpenSSL::Digest::MD5.hexdigest(output)
  	return output
	else
  	return "-1"
	end
end

get '/test/:filename.mid' do
  # one day
	cache_control :public, :max_age => 3600
	etag ""
  @@grid_pool.with do |grid_handle|
  	begin
  		grid_handle.open(params[:filename],"r") { |f| (output = output + f.read) }
  	rescue => e
			return 0
  	end
	end
  return '1' if output.length > 0
	return '0'
end

# get '/add/:auth/:filename' do
# Get Artist, Title, Album, Year
# Read the file
# get md5
# verify md5 isn't already in db
# if it is verify sha1
# if it is verify sha512
# if they are don't add it
# return wwfileid of matching file if match
# get new wwfileid if not
# set artist, title, track, album, year, md5, sha1, sha512 in network db
# add file to gridfs

post '/add' do
wwfileid = ''
	unless 	params[:url] && 
					params[:year] && 
					params[:album] && 
					params[:artist] && 
					params[:title] && 
					params[:file] && 
					(tmpfile = params[:file][:tempfile]) && 
					(name = params[:file][:filename])
		return "-1".to_json
	end
	
	while blk = tmpfile.read(65536)
   (file = file + blk)
  end
	
	my_md5 = OpenSSL::Digest::MD5.hexdigest(file)
  wwfileid = (JSON.parse(RestClient.post "#{NETWORK_SERVICES_URL}/api/verify_file_md5", :hash => my_md5).first)['WWFILEID']	
	
	#if wwfileid = -1 then it's a new file
  unless wwfileid == -1
	unless (JSON.parse(RestClient.post "#{NETWORK_SERVICES_URL}/api/verify_file_sha1", :hash => OpenSSL::Digest::SHA1.hexdigest(file)).first)['WWFILEID'] == -1
	unless (JSON.parse(RestClient.post "#{NETWORK_SERVICES_URL}/api/verify_file_sha512", :hash => OpenSSL::Digest::SHA512.hexdigest(file)).first)['WWFILEID'] == -1
		# it's a duplicate
		return wwfileid.to_json
	end
	end
	end

	new_fid = JSON.parse(RestClient.post "#{NETWORK_SERVICES_URL}/api/create_file", '' ).first	

	wwfileid = new_fid['WWFILEID']
  sid = new_fid['sid']

  md5 = OpenSSL::Digest::MD5.hexdigest(file)
	sha1 = OpenSSL::Digest::SHA1.hexdigest(file)
  sha512 = OpenSSL::Digest::SHA512.hexdigest(file)

	RestClient.post "#{NETWORK_SERIVCES_URL}/api/add_file_to_network", 	:wwfileid => wwfileid, :random_hash => sid, :title => params[:title], :artist => params[:artist], :album => params[:album], :year => params[:year], :md5 => md5, :sha1 => sha1, :sha512 => sha512

  #wwfileid = file.md5 #this will come from network services later
  
  @@grid_pool.with do |grid_handle|
      grid_handle.open(wwfileid,"w",{ :metadata => { :md5 => md5, :sha1 => sha1, :sha512 => sha512 } }) { |f| f.write(file) }
    end
  end
tmpfile.close
tmpfile.unlink
return wwfileid.to_json
end

