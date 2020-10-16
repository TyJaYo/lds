#!/usr/bin/env ruby

require 'nokogiri'

#CONFIG
TARGET_DIRECTORY = '/Users/tyleryoung/Downloads/Final Security SY0-601 Content/'
htmls = Dir.glob ("#{TARGET_DIRECTORY}*.html")

#HELPER
def noko(html)
  html = html.gsub('<ol>',"<ol class='decimal'>") # explicitly declare list type
  doc = Nokogiri::HTML(html)

  doc.search('head').each(&:remove) #remove <head>

  doc.search('script').each(&:remove) #remove <script>

  doc.search('span[class="ql-cursor"]').each(&:remove) #remove <span class="ql-cursor"></span>

  doc.search('h3').each do |h3| #remove <div> inside <h3>
    content = h3.content
    h3.search('div').each(&:remove)
    h3.content = content
  end

  doc.search('img').each do |image| #remove relative path to images
    image['src'] = image['src'].gsub('assets/','')
  end

  doc.search('span[class="gt-definition"]').add_class('popover-link').each do |span| #create popovers from <span class="gt-definition"
    span.name             = 'a' #change <span> to <a>
    span['data-content']  = span.delete('def-data') #rename 'def-data' attr to 'data-content'
    span['data-html']     = 'true'
    span['data-toggle']   = 'popover'
  end

  doc = doc.to_html #print
end

#WORKER
htmls.each do |file| #run
  print "#{File.basename(file)} " #readout
  open_file = File.read(file)
  proc_file = noko(open_file)
  File.write(file, proc_file)
end