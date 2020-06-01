	#!/usr/bin/env ruby

require 'nokogiri'
require 'csv'
require 'pry'

### CONFIGURATIONS
HEADER_MAPPINGS = {
	#"0" => "\xEF\xBB\xBFquestion_content_file", This would add BOM to let Excel know the resulting CSVs are UTF-8 but it seems to affect conversion when the XML source file isn't created as UTF-8
	"0" => "name",
	"1" => "content",
	"2" => "voiceover_file"
}
### 

CSV.open("passage_import.csv", "w") do |csv|  #create passage import csv
	csv << HEADER_MAPPINGS.values # put passage import headers on first row of CSV

	Dir["**/*.html"].each do |f| # look through html files in current directory and subs for each html file
		current_file = File.open(f, 'r')
		@doc = Nokogiri::HTML(current_file)
		@doc.remove_namespaces!
		@doc_root = @doc.root || @doc

		h3 = @doc.at_css('h3') # find start of question and name for ease of access
		h2 = @doc.at_css('h2') # find start of question and name for ease of access

		passage_name = h3.text

		ark = h3.add_previous_sibling(Nokogiri::HTML.fragment('<ark><p>Noah</p></ark>')).first # insert tag before h3 for collecting non-passage elements

		next unless @doc.at_css('.cfa-disp-quote') # try to prevent infinite loop

		h3.parent = ark # move question ID into ark
		h2&.parent = ark # move section header into ark if present

		loop do
			break if @doc.css('ark *').any? { |n| n['class'] == 'cfa-disp-quote'} # add elements into ark tag, starting with h3 and ending with div.cfa-disp-quote (metainformation div)
			break unless @doc.at_xpath('//ark').next_element
			@doc.at_xpath('//ark').next_element.parent = ark
		end

		ark.remove

		next if @doc.css('article *').empty? # don't populate CSV row if no passage found

		passage_content = @doc.css('article *').to_s.gsub(/\r/,' ').gsub(/\n/,' ') # store whatever's left as passage

		passage_name << " #{passage_content.split[0].gsub('<p>','')} #{passage_content.split[1]}" # add first two words of passage to name

		### start CSV population
		csv << [ # makes a new row corresponding to current XML item
			passage_name, # question ID + first two words of passage
			passage_content, # whatever's left in the root (article) tag
			'' # voiceover_file
		]
		### end of populate CSV
	end # end of processing one HTML file
end # end of import CSV creation