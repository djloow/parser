#encoding: UTF-8
require 'open-uri'
require 'nokogiri'

catalog_url  = 'http://www.a-yabloko.ru/catalog/'
catalog_html = open(catalog_url)
catalog_doc  = Nokogiri::HTML(catalog_html)
catalog_doc.encoding = 'UTF-8'

groups = []

catalog_doc.css('.children a').each do |group|
  puts group
end
