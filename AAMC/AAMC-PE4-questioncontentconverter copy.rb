#!/usr/bin/env ruby

require 'nokogiri'
require 'csv'
require 'pry'

### CONFIGURATIONS
ROOT_XPATH	= '/Itembank/Items'.freeze
ITEM_HANDLERS = 'Item[@Type="MultipleChoice"]'.freeze
HEADER_MAPPINGS = {
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
	"13" => "external_id"
}
LETTERS = ("A".."Z").to_a
### 

def extract_images(content) # gets the full URL for images in content
	found_images = content.scan(/img[^&]+?src="([^"]+)"/).flatten
end

def sanitize(html) # changes HTML from amp-encoded and cleans up a little
	html = html.gsub('&lt;','<')
	html = html.gsub('&gt;','>')
	html = html.gsub('<p/>','')
	html = html.gsub('<P>','<p>')
	html = html.gsub('</P>','</p>')
	html = html.gsub('<p><p>','<p>')
	html = html.gsub('</p></p>','</p>')
	html = html.gsub('<TABLE>','<table>')
	html = html.gsub('</TABLE>','</table>')
	html = html.gsub('<TR>','<tr>')
	html = html.gsub('</TR>','</tr>')
	html = html.gsub('<TD>','<td>')
	html = html.gsub('</TD>','</td>')
	html = html.gsub('<OL','<ol')
	html = html.gsub('&nbsp;',' ')
	html = html.gsub('</OL>','</ol>')
	html = html.gsub('<LI>','<li>')
	html = html.gsub('</LI>','</li>')
	html = html.gsub('TYPE=I','class="upper-roman"')
	html = html.gsub('type="I"','class="upper-roman"')
	html = html.gsub('type=I','class="upper-roman"')
	html = html.gsub("TYPE='I'",'class="upper-roman"')
	html = html.gsub("Type='I'",'class="upper-roman"')
	html = html.gsub('<I>','<i>')
	html = html.gsub('</I>','</i>')
	html = html.gsub('<p></p>','')
	html = html.gsub('<p> </p>','')
	html = html.gsub('</b> <b>',' ')
	html = html.gsub('</i> <i>',' ')
	html = html.gsub('</i><i>','')
	html = html.gsub('</b><b>','')
	html = html.gsub('<b></b>','')
	html = html.gsub('</b>.','.</b>')
	html = html.gsub(' </b>','</b> ')
	html = html.gsub('<b>','<strong>')
	html = html.gsub('</b>','</strong>')
	html = html.gsub('</i>','</em>')
	html = html.gsub('<i>','<em>')
	html = html.gsub('&amp;','&')
	html = html.gsub('<p><strong> ','<p><strong>')
	html = html.gsub('<p> ','<p>')
	html = html.gsub(/ ?<br><br> ?/,'</p><p>')
	html = html.gsub(/(<img[^>]*src=")[^"]+\/([^"]+?")/,'\1\2')
end

### Grand Totals
files_processed 				= 0
files_with_errors 				= 0
total_questions_processed 		= 0
total_choice_key_mismatch	 	= 0
total_missing_choices			= 0
total_missing_answer 			= 0
total_errors 					= 0

total_error_summary 			= []
###

### process start
Dir["**/*.xml"].each do |f| # Runs on each xml file in current folder and its subdirectories
	### File Totals
	file_questions_processed 	= 0
	file_errors 				= 0
	file_choice_key_mismatch 	= 0
	file_missing_choices		= 0
	file_missing_answer 		= 0
	file_free_response			= 0

	file_error_summary 			= []
	file_image_urls				= []
	###

	puts "***"
	puts "Processing #{f}..."
	puts "***"

	current_file = File.open(f, 'r')
	@doc = Nokogiri::XML(current_file)
	@doc.remove_namespaces!
	@doc_root = @doc.root || @doc
	unless @doc.xpath('//@discipline')
		puts "No discipline found for #{f}"
		file_error_summary << "No discipline found for #{f}"
	end
	
	CSV.open("#{f.chomp(".xml")}_questions.csv", 'w') do |csv| # new CSV with same name as current file
		csv << HEADER_MAPPINGS.values # put question import headers on first row of CSV
		@doc.xpath(ROOT_XPATH).each do |section| # run on each section found in Items in XML
			unless section.xpath('@name') # report if section not present
				err_msg = "No exam name found for Section #{section.xpath('@id')} in #{f}."
				puts err_msg
				file_error_summary << err_msg
			end
			section.xpath(ITEM_HANDLERS).each do |item| # run on each item with certain handler value(s)
				### start of question HTML manipulation
				question = "<p>#{item.xpath('Content/Stem').children.to_html}</p>" # populate question stem to use within question_html
				choices = (1..10).map { |c| item.xpath("Content/Option[@Seq=\"#{c}\"]").children.to_html }.compact.reject { |e| e.to_s.empty? } # create array of answer options out of xml e.g. <value name="choice2">

				if choices.length == 1 # account for illegal choice count coming from Free Response as single option question in XML paradigm
					puts "Only 1 choice found for #{item.xpath('@id')} in #{f}." # report on exception - these have to be changed to FR within BluePrint after import
					file_error_summary << "Only 1 choice found for #{item.xpath('@id')} in #{f}. Created with <!--FR-->." # include exception in summary
					question = "<!--FR-->" + item.xpath('value[@name="question"]').children.to_html.gsub('by hand on paper','below') # add HTML comment to stem and change question instructions
					question_html = "#{question}" # question_html will just be question stem for Free Response
					correct_answer = "F" # populate fake correct_answer to avoid breaking importer
					choices_count = "11" # populate fake choices_count to avoid breaking importer
					file_free_response += 1
				elsif choices.empty? # account for rare cases where no answer options present in source file
					err_msg = "No choices found for #{section.xpath('@id')} in #{f}."
					puts err_msg
					file_error_summary << err_msg
					choices_count = "12" # populate fake choices_count to avoid breaking importer
					file_missing_choices += 1
				else
					answers = (1..choices.length).map { |a| item.xpath("Content/Option[@Seq=\"#{a}\"]").children.to_html }.compact.reject { |e| e.to_s.empty? } # make an array of answer scores to check
					choices_count = choices.length.to_s # set value for choices_count as a string to use in CSV based on how many choices were given in XML
				end
				choices_html = choices.map.each_with_index { |c,t| "<li><div class='multi-choice' data-choice='#{LETTERS[t]}'>#{LETTERS[t]}.</div><div class='choice-content'>#{c}</div></li>" } # make a list item out of each choice
				### end of question and answer HTML manipulation
				
				### start CSV population
				question_html			||= "#{question}<ul class='question-choices-multi'>#{choices_html.join}</ul>" # create full question HTML out of stem and available choices 
				question_category 		= item.xpath('CustomProperties/BankDescription/Value').first&.children&.to_html # use studytopic from XML item if given, otherwise nil and will get overwritten below
				question_type			||= "SMC"
				choices_count			||= "13" #placeholder in case not provided
				exam_name 				= "PT4V1 010119"
				eid 					= item.xpath('@Name').to_s # use Item name as EID

				item_image_urls = extract_images(question_html) # grab image URIs before processing HTML
				file_image_urls += item_image_urls # add image urls from this item to an array for all this file's images

 				correct_answer = LETTERS[item.xpath('Scoring/Keys/Key[@Score="1"]').children.to_s.to_i - 1]

				clean_question_html = sanitize(question_html)

				answer_rat = "<p><strong>The solution is #{correct_answer}.</strong></p><p>#{item.xpath('CustomProperties/WordDocKeyText/Value')&.children}</p>"

				csv << [ # makes a new row corresponding to current XML item
					clean_question_html, # cleans up HTML to populate question_content_file column value
					answer_rat,
					exam_name, # exam_name
					'', # exam_section_name
					question_category, # question_category_name
					'', # sub_question_category_name
					question_type, # question_type
					choices_count, # choices_count
					correct_answer, # correct_answer
					'', # related_lessons
					'', # exam_section_time_allowed
					'', # question_voiceover_file
					'', # answer_voiceover_file
					eid # external_id
				]
				### end of populate CSV
				file_questions_processed += 1
			end # end of item processing
	  	end # end of section processing
	end # end of import CSV creation

	if file_questions_processed < 1 # report if script didn't find anything to work on in XML
		file_errors += 1
		err_msg = "No questions could be processed for this file."
		puts err_msg
		file_error_summary << err_msg
	end

	total_questions_processed += file_questions_processed
	total_choice_key_mismatch += file_choice_key_mismatch
	total_missing_answer += file_missing_answer
	total_missing_choices += file_missing_choices
	file_errors = file_free_response + file_missing_answer + file_choice_key_mismatch + file_missing_choices

	if file_errors > 0 # log errors from this file if there were any
		error_summary_file = File.new("#{f.chomp(".xml")}_errors.txt",'w')
		files_with_errors += 1
		total_errors += file_errors
		total_error_summary << file_error_summary
		file_error_summary.unshift("#{f} had #{file_errors} error(s):")
		error_summary_file.puts(file_error_summary)
	else
		puts "No errors!"
	end # end of error dumping

	unless file_image_urls.empty? # if there are images mentioned in the utilized portions of this XML file
		image_summary_file = File.new("#{f.chomp(".xml")}_images.txt",'w') # make a text file to put image urls in
		image_summary_file.puts(file_image_urls) # write image URLs from this XML to a text file to be downloaded/zipped/uploaded manually
	end

	files_processed += 1
	puts "***"
	puts "#{f} complete"
	puts "#{f} had #{file_errors} file error(s)."
	puts "#{file_questions_processed} question(s) processed."
	puts "Choice/answer mismatch for #{file_choice_key_mismatch} question(s)."
	puts "Missing answers for #{file_missing_answer} question(s)."
	puts "***"
end
puts "*** Analysis complete! ***"
puts "*** Summary:"
puts "#{files_processed} files processed. #{files_with_errors} files had error(s)."
puts "#{total_questions_processed} question(s) processed."
puts "Choice/answer mismatch for #{total_choice_key_mismatch} question(s)."
puts "Missing answers for #{total_missing_answer} total question(s)."

puts "*** Combined Errors Listing:"
total_error_summary.reject { |e| e.empty? }.each { |te| te.each { |e| puts "#{e}" } }