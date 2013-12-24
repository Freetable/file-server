#!/usr/bin/env ruby

require 'rubygems'  
require 'mongo'
require 'sinatra'

set :bind, '0.0.0.0'

include Mongo

grid_handle = GridFileSystem.new(MongoClient.new("localhost", 27017).db('Freetable'))

get '/get/:filename' do
	output = ''
	begin
	grid_handle.open(params[:filename],"r") do |f| output = output + f.read end
	rescue => e
	end
return output
end

get '/test/:filename' do
        output = ''
        begin
        grid_handle.open(params[:filename],"r") do |f| output = output + f.read end
        rescue => e
        end
	return '1' if output.length > 0
	return '0'
end

get '/add/:auth/:filename' do
	# Query ACL list against auth to make sure that the person making the request is accepted
	# Connect to network services and get a list of urls for the file in question
	# Download file
	# Save to GridFS 
	# (Example)
	# Saving IO data
	# file = File.open("me.jpg")
	# id2  = @grid.put(file, 
        # :filename     => "my-avatar.jpg" 
        # :content_type => "application/jpg", 
        # :_id          => 'a-unique-id-to-use-in-lieu-of-a-random-one',
        # :chunk_size   => 100 * 1024,
        # :metadata     => {'description' => "taken after a game of ultimate"})
end

get '/delete/:auth/:filename' do
	# Query ACL list against auth to make sure that the person making the request is accepted
	# grid_handle.delete(:filename);
end

