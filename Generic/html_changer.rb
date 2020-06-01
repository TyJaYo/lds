#!/usr/bin/env ruby

require 'nokogiri'
require 'pry'

#CONFIG
htmls = Dir.glob ('/Users/tyleryoung/Downloads/CFAFP2020L3/L3html/**/*-R*.html')

#HELPER
def noko(html)
  doc = Nokogiri::HTML(html)

  los_list = doc.at_css('ol.lo')

  next if los_list == nil

  next if doc.at_css('h4').content.include?('Learning Outcome')

  los_items = los_list.css('li')

  if los_items.count > 1
    los_list.add_previous_sibling('<h4>Learning Outcomes</h4>')
  else
    los_list.add_previous_sibling('<h4>Learning Outcome</h4>')
  end

  los_items.each { |li| li.content = li.content.gsub(/[\.;] ?$/,'')}

  doc = doc.to_html
end

#WORKER
htmls.each do |file|
  print "#{File.basename(file)}."
  open_file = File.read(file)
  print '.'
  proc_file = noko(open_file)
  print '.'
  File.write(file, proc_file)
  print '. '
end