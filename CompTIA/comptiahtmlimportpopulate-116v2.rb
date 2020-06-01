#!/usr/bin/env ruby

require 'nokogiri'
require 'csv'
require 'pathname'

INPUTPATH = '/Users/tyleryoung/Downloads/CompTIA/COMPTIA-116/CML_Activities_v2.csv'.freeze
OUTPUTPATH = '/Users/tyleryoung/Downloads/CompTIA/COMPTIA-116/CML_Activities_filled.csv'.freeze

folder = Pathname.new("/Users/tyleryoung/Downloads/CompTIA/COMPTIA-116/topics")
files = folder.children("*.html")
CSV.open(OUTPUTPATH, "w") do |csv|

CSV.foreach(INPUTPATH, headers: true) do |row|
	value = row["name"].strip
	file = files.detect do |file|
		file.read.include?("<title>#{value}</title>")
	end	
	file ||= files.detect do |file|
		file.read.include?(">#{value}<")
	end
	value = row["name"].strip.gsub(/^.*?: /,'')
	file ||= files.detect do |file|
		file.read.include?(">#{value}<")
	end
  	row["reading_html_file"] = file.nil? ? "" : file.basename.to_s
	csv << row
end
end