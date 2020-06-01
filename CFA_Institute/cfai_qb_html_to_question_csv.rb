#!/usr/bin/env ruby

require 'nokogiri'
require 'csv'
require 'pry'

### CONFIGURATIONS
HEADER_MAPPINGS = {
	#"0" => "\xEF\xBB\xBFquestion_content_file", This would add BOM to let Excel know the resulting CSVs are UTF-8 but it seems to affect conversion when the XML source file isn't created as UTF-8
	"0" => "question_content_file",
	"1" => "answer_content_file",
	"2" => "exam_name",
	"3" => "exam_section_name",
	"4" => "question_category_name",
	"5" => "sub_question_category_name",
	"6" => "question_type",
	"7" => "choices_count",
	"8" => "correct_answer",
	"9" => "related_lessons",
	"10" => "exam_section_time_allowed",
	"11" => "question_voiceover_file",
	"12" => "answer_voiceover_file",
	"13" => "external_id",
	"14" => "LOS",
	"15" => "SECTION",
	"16" => "CAT2",
	"17" => "LOS2",
	"18" => "SECTION2"
}

LOWER_CASE_LETTERS = ('a'..'z').to_a
### 

CSV.open("question_import.csv", "w") do |csv|  #create question import csv
	csv << HEADER_MAPPINGS.values # put question import headers on first row of CSV

	Dir["**/*.html"].each do |f| # look through html files in current directory and subs for each html file
		current_file = File.open(f, 'r')
		@doc = Nokogiri::HTML(current_file)
		@doc.remove_namespaces!
		@doc_root = @doc.root || @doc

		eid = @doc.at_css('h3').text

		raw_question_content = @doc.at_css('h3 + ul > li').children
		raw_question_content.at_css('p').children.first.add_previous_sibling('<strong>Q.</strong> ')
		clean_question = raw_question_content.to_s.gsub(/\r/,' ').gsub(/\n/,' ')

		correct_answer = @doc.at_css('h3 + ul + p').text.split.first

		answer_upto_meta_css = "h3 + ul + p"

		meta_div = nil
		raw_answer_content = ""

		until meta_div || answer_upto_meta_css.length > 85
			raw_answer_content << @doc.at_css(answer_upto_meta_css).to_s
			meta_div = @doc.at_css("#{answer_upto_meta_css} + div.cfa-disp-quote")
			answer_upto_meta_css << " + *"
		end

		raw_answer_content ||= "#{@doc.at_css('h3 + ul + p')}#{@doc.at_css('h3 + ul + p + p')}#{@doc.at_css('h3 + ul + p + p + p')}"

		question_category_name = File.basename(current_file.path).gsub(/(_MAX.*)/,'')

		if meta_div
			raw_answer_content << meta_div.to_s
			sub_question_category_text = meta_div.at_css('p:first-child').text
			primary_los_letter = meta_div.at_css('p:nth-child(2)').text.gsub(/LOS /,'')
			primary_section = meta_div.at_css('p:nth-child(3)').text.gsub(/Sections? /,'')
			if meta_div.at_css('p:nth-child(4)')
				secondary_question_category_text = meta_div.at_css('p:nth-child(4)').text
				secondary_los_letter = meta_div.at_css('p:nth-child(5)').text.gsub(/LOS /,'')
				secondary_section = meta_div.at_css('p:nth-child(6)').text.gsub(/Sections? /,'')
			end
		else
			puts "some data not found for #{current_file.path}"
		end

		bolded_answer = raw_answer_content.gsub(/([A-C] is correct\.?)/,'<strong>\1</strong>')
		final_answer = bolded_answer.gsub('cfa-disp-quote','cfa-disp-none')

		### start CSV population
		question_type			||= "SMC" # ASSUMPTION: single multiple choice
		choices_count			||= "3" # ASSUMPTION: 3 choices

		csv << [ # makes a new row corresponding to current XML item
			clean_question, # raw + q_dot > clean
			final_answer, # raw > bolded > final
			'', # exam_name
			'', # exam_section_name
			question_category_name, # question_category_name from filename
			sub_question_category_text, # sub_question_category_name from first category listed in metadata
			question_type, # question_type (assumed SMC)
			choices_count, # choices_count (assumed 3)
			correct_answer, # first letter in raw answer explanation
			'', # related_lessons
			'', # exam_section_time_allowed
			'', # question_voiceover_file
			'', # answer_voiceover_file
			eid, # content of h3 (question <title> in XML)
			primary_los_letter, # first LOS found under subcat in metadata
			primary_section, # first section number found under subcat
			secondary_question_category_text,
			secondary_los_letter,
			secondary_section
		]
		### end of populate CSV
	end # end of processing one HTML file
end # end of import CSV creation