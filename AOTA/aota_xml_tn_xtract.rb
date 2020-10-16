#!/usr/bin/env ruby

require 'nokogiri'
require 'csv'
require 'pathname'

INPUTPATH = '/Users/tyleryoung/Downloads/aota_items/csv/all_aota_questions_no_clin_sim.csv'.freeze
OUTPUTPATH = '/Users/tyleryoung/Downloads/aota_items/csv/all_aota_questions_no_clin_sim_filled.csv'.freeze

folder = Pathname.new("/Users/tyleryoung/Downloads/aota_items")
files = folder.children.select { |a| a.to_s.match(/\.xml/) }
CSV.open(OUTPUTPATH, "w") do |csv|
	CSV.foreach(INPUTPATH, headers: true) do |row|
		value = row["external_id"].strip
		file = files.detect do |file|
			file.read.include?(value)
		end	
		row["task_number"] = file.nil? ? "" : file.read[/task="([^"]*?)"/,1]
		csv << row
	end
end