require 'open-uri'
require 'nokogiri'

catalog_url  = 'http://www.a-yabloko.ru/catalog/'
catalog_html = open(catalog_url)
catalog_doc  = Nokogiri::HTML(catalog_html)

puts catalog_doc
