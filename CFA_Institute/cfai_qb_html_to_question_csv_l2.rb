#!/usr/bin/env ruby

require 'Pathname'
require 'nokogiri'
require 'csv'

INPUT_DIR = '/Users/tyleryoung/Downloads/CFA2020QB/QB_LII'
@images_ingested = true

class CfaQbHtmlProcessor
  OUTPUT_DIR  = "#{INPUT_DIR}/generated_import_csvs"
  TIMESTAMP   = Time.new.strftime('%d_%k%M')
  Q_OUTPUT_FILE = "#{OUTPUT_DIR}/questions#{TIMESTAMP}.csv"
  P_OUTPUT_FILE = "#{OUTPUT_DIR}/passages#{TIMESTAMP}.csv"
  LETTERS     = ("A".."Z").to_a
  Q_HEADERS     = [
    'external_id',
    'question_content_file',
    'answer_content_file',
    'question_type',
    'question_category_name',
    'sub_question_category_name',
    'choices_count',
    'correct_answer',
    'passage_name',
    'exam_name'
  ]
  P_HEADERS     = [
    'name',
    'content'
  ]
  def initialize(file_path)
    @file_path          = Pathname(file_path)
    @q_csv_rows         = []
    @p_csv_rows         = []
    @done_passage_names = []
  end
  def process
    puts TIMESTAMP
    extract_html_in_order
    export_q_csv
    export_p_csv
  end
  def los_headr(meta_block)
    ps = meta_block.css('p')
    rd_name = ps.first.content.gsub('–','&ndash;').gsub(/([IV])\-([IV])/,'\1&ndash;\2')
    if ps[1].text.include?(',')
      los_head = "#{rd_name} Learning Outcomes"
    else
      los_head = "#{rd_name} Learning Outcome"
    end
  end
  def extract_html_in_order
    all_files = Dir.glob("#{@file_path.to_s}/**/*.{html,HTML}")
    sorted_files = all_files.sort
    extract_html(sorted_files)
  end
  def sanitize_children(node)
    node = node.children.to_html.gsub(/\n/,'').gsub(/ {2,}/,' ')
  end
  def extract_html(html_files)
    html_files.each do |html_file|
      doc  = Nokogiri::HTML(File.open(html_file))
      passage = doc.at_css('div')
      passage_name = passage['id']
      passage.at_css('h3').remove
      if passage.at_css('h2') # remove section instructions if present
        passage.at_css('h2 + p + hr')&.remove # remove line below section instructions, but don't shut down if it's not there
        passage.at_css('h2 + p').remove # remove section instruction paragraph
        passage.at_css('h2').remove # remove section header
      end
      items = passage.xpath('./section').each(&:remove)
      if passage.at_css('img') && @images_ingested == false
        imgs = passage.css('img')
        imgs.each do |i|
          i['data-external'] = "true"
          puts "passage #{passage_name} needs #{i['src']}"
        end
      end
      passage = passage.to_html
      items.each do |item|
        xid = item.at_css('h4').content
        item.at_css('h4').content = 'Solution'
        if item.at_css('img') && @images_ingested == false
          imgs = item.css('img')
          imgs.each do |i|
            i['data-external'] = "true"
            puts "item #{xid} needs #{i['src']}"
          end
        end
        answer_content_file = item

        question_content_file = answer_content_file.at_css('ul').remove
        question_content_file = question_content_file.at_css('li')
        question_content_file.at_css('p')['class'] = 'cfa-stem'
        question_content_file = sanitize_children(question_content_file)

        question_category_name = answer_content_file.at_css('div.cfa-disp-quote > p').content.gsub('–','&ndash;').gsub(/([IV])\-([IV])/,'\1&ndash;\2')
        answer_content_file.at_css('div.cfa-disp-quote')['class'] = 'cfa-meta-block'
        los_head = los_headr(answer_content_file.at_css('div.cfa-meta-block'))
        answer_content_file.at_css('div.cfa-meta-block').add_next_sibling("<h4>#{los_head}</h4>")
        correct_answer = answer_content_file.at_css('p').text[0]

        if answer_content_file.at_css('div.cfa-p')
          bold_p = answer_content_file.at_css('div.cfa-p').to_html
          bold_p = Nokogiri::HTML::fragment(bold_p.sub(/([A-Z] is correct.)/,'<strong>\1</strong>'))
          answer_content_file.at_css('div.cfa-p').replace(bold_p)
        else
          bold_p = answer_content_file.at_css('p').to_html
          bold_p = Nokogiri::HTML::fragment(bold_p.sub(/([A-Z] is correct.)/,'<strong>\1</strong>'))
          answer_content_file.at_css('p').replace(bold_p)
        end

        answer_content_file = sanitize_children(answer_content_file)

        exam_name = File.basename(html_file).sub(/_.*/,'')

        q_row = [
          xid, #external_id
          question_content_file,
          answer_content_file,
          'SMC', # question_type
          question_category_name,
          '', #sub_question_category_name
          '3', #choices_count
          correct_answer,
          passage_name,
          exam_name
        ]
        @q_csv_rows << q_row
        p_row = [
          passage_name, #name
          passage #content
        ]
        @p_csv_rows << p_row
      end
    end
  end
  def export_q_csv
    csv = CSV.open(Q_OUTPUT_FILE, 'w')
    csv << Q_HEADERS
    @q_csv_rows.each { |row| csv << row }
  end
  def export_p_csv
    csv = CSV.open(P_OUTPUT_FILE, 'w')
    csv << P_HEADERS
    @p_csv_rows.each do |row| 
      csv << row unless @done_passage_names.include?(row[0])
      @done_passage_names << row[0]
    end
  end
end

processor  = CfaQbHtmlProcessor.new(INPUT_DIR)
processor.process