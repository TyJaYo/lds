#!/usr/bin/env ruby
require 'nokogiri'

#CONFIG
target_dir = '/Users/tyleryoung/Downloads/CFA Level I (2022) 10211/CFA-FP-2022-LI-HTML'
htmls      = Dir.glob ("#{target_dir}**/*-P*.html")
contribs   = Dir.glob ("#{target_dir}**/*-R*contrib-groups.html")

#HELPER METHODS
def los_proc(html)
  doc = Nokogiri::HTML.fragment(html)
  los_list = doc.at_css('ol.lo')
  return doc.to_html if los_list == nil
  return doc.to_html if doc.at_css('h4')&.content&.include?('Learning Outcome')
  los_items = los_list.css('li')
  if los_items.count > 1
    los_list.add_previous_sibling('<h4>Learning Outcomes</h4>')
  else
    los_list.add_previous_sibling('<h4>Learning Outcome</h4>')
  end
  los_items.each { |li| li.at_css('span').content = li.content.gsub(/[\.;]\p{Zs}*/,'')}
  return doc.to_html
end

def add_ref_header(html)
  doc = Nokogiri::HTML.fragment(html)
  ref_list = doc.at_css('ol[@id*="-ref"]')
  return doc.to_html if ref_list == nil
  return doc.to_html if doc.at_css('h2')&.content&.include?('Reference')
  los_items = ref_list.css('li')
  if los_items.count > 1
    ref_list.add_previous_sibling('<h2>References</h2>')
  else
    ref_list.add_previous_sibling('<h2>Reference</h2>')
  end
  return doc.to_html
end

def pound_pdf_ref(file)
  doc = Nokogiri::HTML.fragment(file)
  doc.css('a[href$=".pdf"]').each do |link|
    link.attributes["href"].value += "#"
  end
  return doc.to_html
end

def externalize_imgs(file)
  doc = Nokogiri::HTML.fragment(file)
  doc.css('img').each do |img|
    img['data-external'] = 'false'
  end
  return doc.to_html
end

def remove_empty_hrefs(file)
  doc = Nokogiri::HTML.fragment(file)
  doc.search('a[href=""]').each(&:remove)
  return doc.to_html
end

def remove_empty_paras(file)
  file = file.gsub(/<p>\p{Zs}*<\/p>/,'')
  return file
end

def minus_signify(file)
  file = file.gsub(/(\p{Zs}|<td[^>]*?>)(–|&#8211;|&#x2013;|&ndash;)([\s\d%][^A-Z])/,'\1&minus;\3')
  return file
end

def insert_contribs(file,file_name)
  doc = Nokogiri::HTML.fragment(file)
  return doc.to_html if doc.at_css('div.cfa-contrib')
  file_key = file_name.gsub(/-R.*/,'')
  node_to_insert = @cg_hash[file_key]
  if not node_to_insert
    puts "no contrib-group found for #{file_name}"
    return doc.to_html
  end
  header_to_follow = doc.at_css('h2')
  header_to_follow.add_next_sibling(node_to_insert)
  return doc.to_html
end

#WORKER METHODS
def hash_contribs(contribs)
  @cg_hash = {}
  contribs.each do |file|
    open_file = File.read(file)
    gsub_file = open_file.gsub("\n\n","\n")
    doc = Nokogiri::HTML.fragment(gsub_file)
    contrib_div = doc.at_css('div.cfa-contrib')
    contrib_file_key = File.basename(file).gsub(/-R.*contrib-groups.html/,'')
    @cg_hash[contrib_file_key] = contrib_div
  end
end

def proc_htmls(htmls)
  htmls.each do |file|
    file_name = File.basename(file)
    str_file  = File.read(file)
    str_file  = remove_empty_paras(str_file)
    str_file  = minus_signify(str_file)
    proc_file = los_proc(str_file)
    proc_file = pound_pdf_ref(proc_file)
    proc_file = externalize_imgs(proc_file)
    proc_file = remove_empty_hrefs(proc_file)
    proc_file = add_ref_header(proc_file)
    proc_file = insert_contribs(proc_file,file_name) if file_name.include?('-R-s01.html')
    File.write(file,proc_file)
  end
end

#PROGRAM RUN
hash_contribs(contribs)
proc_htmls(htmls)