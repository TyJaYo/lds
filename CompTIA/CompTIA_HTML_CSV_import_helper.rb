#!/usr/bin/env ruby

require 'csv'
require 'pry'

pwd_html_files = Dir.glob "**/*.html" # find all HTML files in or under current directory and store them as an array
pwd_csv_files = Dir.glob "**/*.csv" # find all CSVs in or under current directory and store them as an array
pwd_csv_files.each do |og_csv_file| # for each CSV file...
  next if og_csv_file.include?("_filled") # ...unless it's an output file...
  og_csv_file = og_csv_file.encode("UTF-8", "Windows-1252") # ...attempt to transcode from default Excel CSV save to UTF-8
  filled_csv = File.new("#{File.basename(og_csv_file,".csv")}_filled.csv",'w') # create a new CSV with the name of the original + "_filled" (and make it writable)
  og_csv_table = CSV.parse(File.read(og_csv_file), headers: true) # parse the file as a CSV with headers, returning a CSV::Table object
  CSV.open(filled_csv, 'w') # copy headers to new file
  filled_csv_table = CSV.parse(File.read(filled_csv), headers: true) # parse the new file as a CSV with headers, returning a CSV::Table object
  column_count = og_csv_table.headers.length
  og_csv_table.length.times do |r| # for each row after the header in the original file...
    filled_csv_table << Array.new(column_count) { Array.new } # pre-populate an empty array in the destination file, then...
    column_count.times do |c| # ...for each column...
      filled_csv_table.by_col[c][r] << og_csv_table.by_col[c][r] # ...take that row's value for that column from the old file and write it to the new file
    end 
    row_name = og_csv_table["name"][r].gsub(/.*?: /,'') # store the value of that row's "name" field, minus text before colon (and space after colon)
    # binding.pry
    file_best_guess = nil # initialize variable here in case not found
    if og_csv_table["reading_html_file"][r] == nil # but then if the value for reading_html_file isn't there for that row
      pwd_html_files.each do |file| # go through each file in HTML file array...
        if File.read(file).include?("<title>#{row_name}</title>") # ...and if it includes the row name as the title
          file_best_guess = file # ...store that file's name as the best guess
        end
      end
      filled_csv_table["reading_html_file"][r] = file_best_guess # populate best guess to the value for reading_html_file
    end
    if og_csv_table["reading_html_file"][r] == nil # but then if the value for reading_html_file STILL isn't there for that row
      pwd_html_files.each do |file| # go through each file in HTML file array...
        if File.read(file).include?("<span>#{row_name}</span>") # ...and if it includes the row name as a span
          file_best_guess = file # ...store that file's name as the best guess
        end
      end
      filled_csv_table["reading_html_file"][r] = file_best_guess # populate best guess to the value for reading_html_file
    end
  end


  filled_csv << og_csv_table.headers.to_csv
  filled_csv_table.each { |f| filled_csv << f.to_s.gsub(/[\[\]\"]/,'') }

end