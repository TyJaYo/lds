#!/usr/bin/env ruby

require 'Pathname'
require 'nokogiri'
require 'csv'
require 'pry'

INPUT_DIR = '/Users/tyleryoung/Downloads/CFA2020QB/QB_LI'
@images_ingested = true

class CfaQbHtmlProcessor
  OUTPUT_DIR  = "#{INPUT_DIR}/generated_import_csvs"
  TIMESTAMP   = Time.new.strftime('%d_%k%M')
  Q_OUTPUT_FILE = "#{OUTPUT_DIR}/questions#{TIMESTAMP}.csv"
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
    'exam_name'
  ]
  P_HEADERS     = [
    'name',
    'content'
  ]
  def initialize(file_path)
    @file_path          = Pathname(file_path)
    @q_csv_rows         = []
  end
  def process
    puts TIMESTAMP
    extract_html_in_order
    export_q_csv
  end
  def amp_contents(node)
    node = node.content.gsub('–','&ndash;').gsub(/([IV])\-([IV])/,'\1&ndash;\2')
  end
  def los_headr(meta_block)
    ps = meta_block.css('p')
    rd_name = amp_contents(ps.first)
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
  def clean_children_to_html(node)
    node = node.children.to_html.gsub(/\n/,'').gsub(/ {2,}/,' ').strip
  end
  def boldify(node,*targets)
    targets.each do |target|
      if node.at_css(target)
        bold_p = node.at_css(target).to_html
        if bold_p.match(/[A-C] is correct/)
          @correct_answer = node.at_css(target).text[0]
          bold_p = Nokogiri::HTML::fragment(bold_p.sub(/([A-C] is correct[\.,;]?)/,'<strong>\1</strong>'))
          node.at_css(target).replace(bold_p)
        end
      end
    end
  end
  def extract_html(html_files)  
    html_files.each do |html_file|  
      doc  = Nokogiri::HTML(File.open(html_file)) 
      
      container = doc.at_css('div') 
      
      if container.at_css('h2') # remove section instructions if present  
        container.at_css('h2 + p + hr')&.remove # remove line below section instructions, but don't shut down if it's not there 
        container.at_css('h2 + p').remove # remove section instruction paragraph  
        container.at_css('h2').remove # remove section header 
      end
      
      xid = container.at_css('h3').content
      
      container.at_css('h3').content = 'Solution'
      container.at_css('h3').name = 'h4'
      
      if container.at_css('img') && @images_ingested == false
        imgs = container.css('img')
        imgs.each do |i|
          i['data-external'] = "true"
          puts "item #{xid} needs #{i['src']}"
        end
      end

      until container.at_css('h4 + ul')
        container.at_css('ul > li > *:first-child').add_previous_sibling(container.at_css('h4 + *'))
      end

      item = container.at_css('ul > li').remove

      container.at_css('ul').remove
      
      if item.at_xpath('./p') 
        item.at_xpath('./p').add_class('cfa-stem')
      else
        item.at_css('div.cfa-p').add_class('cfa-stem')
      end
      
      question_content_file = clean_children_to_html(item)

      answer_content_file = container

      question_category_name = amp_contents(answer_content_file.at_css('div.cfa-disp-quote > p'))
      
      answer_content_file.at_css('div.cfa-disp-quote')['class'] = 'cfa-meta-block'
      
      los_head = los_headr(answer_content_file.at_css('div.cfa-meta-block'))
      answer_content_file.at_css('div.cfa-meta-block').add_next_sibling("<h4>#{los_head}</h4>")
      

      boldify(answer_content_file,'div.cfa-p','p')

      answer_content_file = clean_children_to_html(answer_content_file)

      exam_name = File.basename(html_file).sub(/_.*/,'')

      q_row = [
        xid, #external_id
        question_content_file,
        answer_content_file,
        'SMC', # question_type
        question_category_name,
        '', #sub_question_category_name
        '3', #choices_count
        @correct_answer,
        exam_name
      ]
      @q_csv_rows << q_row
    end
  end
  def export_q_csv
    csv = CSV.open(Q_OUTPUT_FILE, 'w')
    csv << Q_HEADERS
    @q_csv_rows.each { |row| csv << row }
  end
end
processor  = CfaQbHtmlProcessor.new(INPUT_DIR)
processor.process