#!/usr/bin/env ruby

require 'csv'
require 'pry'

htmls = Dir.glob "**/*.html" # find all HTML files in or under current directory and store them as an array
csvs = Dir.glob "**/*.csv" # find all CSVs in or under current directory and store them as an array
csvs.each do |csv| # for each CSV file...
  next if csv.include?("_filled") # ...unless it's an output file...
  csv = csv.encode('UTF-8', 'Windows-1252') # transcode it from default Excel save to UTF-8
  @row_number = 0
  output_file = csv.gsub('.csv','_filled.csv')
  CSV.open(output_file, 'w', encoding:'UTF-8') do |csv_out| 
    CSV.foreach(csv) do |row|  
      @row_number += 1
      row[1] = row[1].strip
      row_name = row[1].strip.gsub(/.*?: /,'') # store the value of that row's "name" field, minus text before colon (and space after colon)

      if row[3] == nil # but then if the value for reading_html_file isn't there for that row
        row_name_for_regex = row_name.gsub('/','\/').gsub(/[\u0080-\uffff]/, '')
        # if row_name == 'Proprietary/Closed-source Intelligence Sources'
          # binding.pry
        # end
        htmls.each do |file| # go through each file in HTML file array...
          if File.read(file).match(Regexp.new("> *?#{row_name_for_regex} *?<")) # ...and if it includes the row name as the title
            row[3] ||= File.basename(file)
          end
          # if @row_number == 270 && File.basename(file) == '32624591-dd7a-4f70-91b3-0d574aca24df.html'
          #   binding.pry
          # end
          # if File.basename(file) == '32624591-dd7a-4f70-91b3-0d574aca24df.html'
          #   binding.pry
          # end
          # puts row[1]
          # break if row[3] != nil
        end
        row[3] ||= 'not_found'  # reading_html_file
      end
      csv_out << row
      # if og_csv_table["reading_html_file"][r] == nil # but then if the value for reading_html_file STILL isn't there for that row
      #   pwd_html_files.each do |file| # go through each file in HTML file array...
      #     if File.read(file).include?("<span>#{row_name}</span>") # ...and if it includes the row name as a span
      #       file_best_guess = file # ...store that file's name as the best guess
      #     end
      #   end
      #   filled_csv_table["reading_html_file"][r] = file_best_guess # populate best guess to the value for reading_html_file
      # end
    end
# binding.pry
    csv_out.close
  end

  # filled_csv << og_csv_table.headers.to_csv
  # filled_csv_table.each { |f| filled_csv << f.to_s.gsub(/[\[\]\"]/,'') }

end