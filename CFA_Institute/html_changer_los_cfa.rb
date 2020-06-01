#!/usr/bin/env ruby

require 'nokogiri'

#CONFIG
htmls = Dir.glob ('/Users/tyleryoung/Downloads/CFAFP2020L3/L3html/**/*-R*.html')

#HELPER
def noko(html)
  doc = Nokogiri::HTML(html)

  los_list = doc.at_css('ol.lo')

  return doc.to_html if los_list == nil

  return doc.to_html if doc.at_css('h4')&.content&.include?('Learning Outcome')

  los_items = los_list.css('li')

  if los_items.count > 1
    los_list.add_previous_sibling('<h4>Learning Outcomes</h4>')
  else
    los_list.add_previous_sibling('<h4>Learning Outcome</h4>')
  end

  los_items.each { |li| li.at_css('span').content = li.content.gsub(/[\.;] ?$/,'')}

  doc = doc.to_html
end

#WORKER
htmls.each do |file|
  print "#{File.basename(file)}."
  open_file = File.read(file)
  print '.'
  proc_file = noko(open_file)
  if File.basename(file) == 'AssetAllocationRealWorldConstraints-R_CFA1818-R-s08.html'
    doc = Nokogiri::HTML(proc_file)
    doc.at_css('img#CFA1818-R-EXH9 + div.cfa-attrib').replace(doc.at_css('img#CFA1818-R-EXH9 + div.cfa-attrib').to_s.gsub(': <a href="http://www.vanguard.com/jumppage/targetretirement/TRFCOMM.pdf" target="_blank">www.vanguard.com/jumppage/targetretirement/TRFCOMM.pdf</a>',''))
    proc_file = doc.to_html
  end
  print '.'
  File.write(file, proc_file)
  print '. '
end