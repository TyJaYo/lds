#!/usr/bin/env ruby

require 'Pathname'
require 'nokogiri'
require 'csv'

INPUT_DIR = '/Users/tyleryoung/Dropbox/ISACA/Courses/QAE'

class IsacaXmlProcessor
  OUTPUT_DIR  = "#{INPUT_DIR}/generated_import_csvs"
  TIMESTAMP   = Time.new.strftime('%d_%k%M')
  OUTPUT_FILE = "#{OUTPUT_DIR}/questions#{TIMESTAMP}.csv"
  LETTERS     = ("A".."Z").to_a
  LC_LETTERS  = ("a".."z").to_a
  HEADERS     = [
    'external_id',
    'question_content_file',
    'answer_content_file',
    'question_type',
    'question_category_name',
    'sub_question_category_name',
    'choices_count',
    'correct_answer',
    'course'
  ]
  def initialize(file_path)
    @file_path      = Pathname(file_path)
    @csv_rows       = []
  end
  def process
    puts TIMESTAMP
    extract_html
    export_csv
  end
  def extract_html
    Dir.glob("#{@file_path.to_s}/**/*.{html,HTML}").each do |html_file|
      doc  = Nokogiri::HTML(File.open(html_file))
      cont = doc.at_css('body main div.container div.row div.col-lg-12')
      course = cont.at_css('h2 span').content.gsub('Course: ','')
      items = cont.css('div')
      items.each do |item|
        xid = item.at_css('h3').content.match(/[A-Z]\d{4}/).to_s
        xid = item.at_css('h4:contains("Editor Notes:") + p').content.match(/\w\d{4}/).to_s if xid.empty?
        xid = item.at_css('h4:contains("Editor Notes:") + p + p').content.match(/\w\d{4}/).to_s if xid.empty? && item.at_css('h4:contains("Editor Notes:") + p + p')
        xid = "no ID found" if xid.empty?
        if item.at_css('img')
          imgs = item.css('img')
          imgs.each do |i|
            i['src'] = i['src'].sub(/.*\/(.*?$)/,'\1')
            i['data-external'] = "true"
            puts "#{course} item #{xid} needs #{i['src']}"
          end
        end
        question_stims = []
        question_stims << item.at_css('h4:contains("Question Statement:") + p')&.to_html
        question_stims << item.at_css('h4:contains("Question Statement:") + p + p')&.to_html
        question_stims << item.at_css('h4:contains("Question Statement:") + p + p + p')&.to_html
        question_stims << item.at_css('h4:contains("Question Statement:") + p + p + p + p')&.to_html
        answer_options = []
        item.css('td + td').each { |o| answer_options << o.content.strip }
        choices_count = answer_options.size
        correct_text = item.at_css('td:contains(">>") + td').content.strip
        correct_index = answer_options.index(correct_text)
        correct_answer = LETTERS[correct_index]
        list_items = []
        choices_count.times do |t| 
          list_items << "<li>#{answer_options[t]}</li>"
        end
        question_content_file = "#{question_stims.join}<ol>#{list_items.join}</ol>"
        ans_ps = item.css('h5:contains("English") ~ p')
        ans_exps = []
        ans_ps.each { |p| ans_exps << p.content.sub(/^.*?is (in)?correct\. /,'') }
        ans_exps = ans_exps.insert(correct_index, ans_exps.delete_at(0))
        ans_lis = []
        choices_count.times do |t| 
          ans_lis << "<li>#{ans_exps[t]}</li>"
        end
        ans_intro = "<p class='cor-ans'>#{correct_answer} is the correct answer.</p><h4 class='just'>Justification</h4>"
        ans_exp_list = "<ol class='cor-ans-#{correct_answer.downcase}'>#{ans_lis.join}</ol>"
        answer_content_file = "#{ans_intro}#{ans_exp_list}"
        row = [
          xid, #external_id
          question_content_file,
          answer_content_file,
          'SMC', # question_type
          '', #question_category_name
          '', #sub_question_category_name
          choices_count,
          correct_answer,
          course
        ]
        @csv_rows << row
      end
    end
  end
  def export_csv
    csv = CSV.open(OUTPUT_FILE, 'w')
    csv << HEADERS
    @csv_rows.each { |row| csv << row }
  end
end
processor  = IsacaXmlProcessor.new(INPUT_DIR)
processor.process