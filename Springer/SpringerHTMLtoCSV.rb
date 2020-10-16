#!/usr/bin/env ruby

require 'Pathname'
require 'nokogiri'
require 'csv'

INPUT_DIR = '/Users/tyleryoung/Downloads/9780826164575_BitsXML_2020_09_10_11_43_50'

class SpringerHTMLProcessor
  OUTPUT_DIR  = "#{INPUT_DIR}/generated_import_csvs"
  TIMESTAMP   = Time.new.strftime('%d_%k%M')
  OUTPUT_FILE = "#{OUTPUT_DIR}/questions#{TIMESTAMP}.csv"
  HEADERS     = [
    'question_content_file',
    'question_category_name',
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
      items = doc.css('div')
      items.each do |item|
      	question_content_file = html_file
        question_category_name = item['content-type']
        row = [
          question_content_file,
          question_category_name
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
processor  = SpringerHTMLProcessor.new(INPUT_DIR)
processor.process