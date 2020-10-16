#!/usr/bin/env ruby
require 'Pathname'
require 'nokogiri'
require 'csv'

INPUT_DIR = '/Users/tyleryoung/Downloads/2021_CIPM_NewReadings/XML/CIPM L2'

class CfaXmlProcessor
  OUTPUT_DIR  = '/Users/tyleryoung/Downloads/2021_CIPM_NewReadings'
  TIMESTAMP   = Time.new.strftime('%d_%k%M')
  OUTPUT_FILE = "#{OUTPUT_DIR}/lessons#{TIMESTAMP}.csv"
  HEADERS     = [
    'id',
    'name',
    'parent_section_id',
    'reading_html_file'
  ]
  def initialize(file_path)
    @file_path      = Pathname(file_path)
    @keyed_files    = []
    @topic_intros   = []
    @all_lessons    = []
    @csv_rows       = []
    @ss_num = 0
    @r_prev ||= 42
  end
  def process
    build_book_map
    create_categories
    build_rows
    export_csv
  end
  def build_book_map
    Dir.glob("#{@file_path.to_s}/**/*.{xml,XML}").each do |xml_file|
      doc = Nokogiri::XML(File.open(xml_file))

      # extract book numbers and book types from xml file

      outer_type    = doc.at_xpath('book/body/book-part/@book-part-type').value
      outer_number  = doc.at_xpath('book/body/book-part/@book-part-number').value
      inner_type    = doc.at_xpath('book/body/book-part/body/book-part/@book-part-type').value
      inner_number  = doc.at_xpath('book/body/book-part/body/book-part/@book-part-number')&.value
      inner_number  ||= 0
      group_title   = doc.at_xpath('book/body/book-part/body/book-part/book-part-meta/title-group/title').content
      sections      = doc.xpath('book/body/book-part/body/book-part/body/sec')
      back_sections = doc.xpath('book/body/book-part/body/book-part/body/back/sec')
      ref_sections  = doc.xpath('book/body/book-part/body/book-part/body/back/ref-list')
      
      if back_sections
        sections += back_sections
      end

      if ref_sections
        sections += ref_sections
      end

      file_titles  = []
      file_names   = []

      sections.each do |sec|
        file_titles << sec.at_xpath('./title').content.chomp('11 This section based on Chapter 6 in Essays on Manager Selection, by Scott D. Stewart, PhD, CFA, Research Foundation of CFA Institute. © 2013 CFA Institute. All rights reserved. ')
        file_names  << "#{File.basename(xml_file, ".*")}_#{sec.at_xpath('@id')}.html".gsub(/_CFA\d{4}-R-ref/,'-ref')
      end

      book_part_data = {
        outer_number: outer_number.to_i,
        inner_number: inner_number.to_i,
        outer_type:   outer_type,
        inner_type:   inner_type,
        group_title:  group_title,
        file_titles:  file_titles,
        file_names:   file_names
      }
      book_part_data.default = 'not_found'

      @keyed_files << book_part_data
    end
  end
  def create_categories
    #Topic Intros
    @topic_intros = @keyed_files.select { |h| h[:outer_type] == 'topic' }.uniq { |h| h[:outer_number] }.sort_by { |h| h[:outer_number] }

    #Study Sessions with Intros and Readings inside
    ss_files = @keyed_files.select { |h| h[:outer_type] == 'study_session' }.sort_by { |h| h[:outer_number] }

    ss_count = ss_files.uniq { |h| h[:outer_number] }.count
    first_ss_n = ss_files[0][:outer_number]
    ss_count.times do |i|
      ssn = i + first_ss_n
      nth_study_session_files = ss_files.select { |h| h[:outer_number] == ssn }
      next if nth_study_session_files.empty?

      #Study Session Intro
      ss_intro = nth_study_session_files.select { |h| h[:inner_type] == 'ss_intro' }.first
      @all_lessons.append(ss_intro)

      #Study Session Readings
      study_session_readings = nth_study_session_files.select { |h| h[:inner_type] == 'reading'}.sort_by { |h| h[:inner_number] }
      first_reading_n = study_session_readings[0][:inner_number]
      study_session_readings.count.times do |ii|
        rn = ii + first_reading_n
        nth_reading_pages = nth_study_session_files.select { |h| h[:inner_number] == rn }
        reading_los = nth_reading_pages.select { |h| h[:inner_type] == 'los' }.first
        reading_r = nth_reading_pages.select { |h| h[:inner_type] == 'reading' }.first
        reading_prob = nth_reading_pages.select { |h| h[:inner_type] == 'probs' }.first
        @all_lessons.append(reading_los) unless reading_los == nil
        @all_lessons.append(reading_r) unless reading_r == nil
        @all_lessons.append(reading_prob) unless reading_prob == nil
      end

    end
  end
  def build_rows
    #Topic Intros
    @topic_intros.each do |topic_intro|
      t_code = "TO#{topic_intro[:outer_number]}"
      @csv_rows << [t_code, "#{t_code} #{topic_intro[:group_title]}", nil, nil] # parent category layer (TO{#} {Name})
      @csv_rows << ["#{t_code}I", 'Introduction', t_code, nil]                  ### subcategory layer (Introduction)
      topic_intro[:file_titles].count.times do |t|
        @csv_rows << [nil, topic_intro[:file_titles][t], "#{t_code}I", topic_intro[:file_names][t]]
      end
    end

    #All Lessons
    @all_lessons.each do |lesson|
      # Study Session / Intro
      next if lesson == nil
      if lesson[:inner_number] == 0 # make Study Session category and first subcat (Introduction)
        @ss_num = lesson[:outer_number] # set counter to current study session
        ss_code = "SS#{@ss_num}"
        @csv_rows << [ss_code, "#{ss_code} #{lesson[:group_title]}", nil, nil] # parent category layer (SS{#} {Study Session Name})
        @csv_rows << ["#{ss_code}I", 'Introduction', ss_code, nil]             ### subcategory layer (Introduction)
        lesson[:file_titles].count.times do |t|
          @csv_rows << [nil, 'Study Session Opener', "#{ss_code}I", lesson[:file_names][t]]
        end
        next #move on to next lesson
      end
     
      if lesson[:outer_number] == @ss_num # Readings in same Study Session
      # Lessons in same Reading
        r_num = lesson[:inner_number] # set counter to current reading based on active file
        r_code = "R#{r_num}"                                                   ### subcategory layer (R{#} {Reading Name})
        @csv_rows << [r_code, "#{r_code} #{lesson[:group_title]}", "SS#{@ss_num}", nil] unless r_num == @r_prev
        @r_prev = r_num
        if lesson[:inner_number] == r_num
          lesson[:file_titles].count.times do |t| # for every section...       ##### lesson layer ({Lesson Name})
            @csv_rows << [nil, lesson[:file_titles][t], r_code, lesson[:file_names][t]]
          end
        end
      end
    end

    # @csv_rows << [id, title, parent_section_id, file_name]
  end
  def export_csv
    csv = CSV.open(OUTPUT_FILE, 'w')
    csv << HEADERS
    @csv_rows.each { |row| csv << row }
  end
end
processor  = CfaXmlProcessor.new(INPUT_DIR)
processor.process