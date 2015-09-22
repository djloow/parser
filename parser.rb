require 'open-uri'
require 'nokogiri'
require 'digest'
require 'mechanize'

catalog_url  = 'http://www.a-yabloko.ru/catalog/' # кодировка страницы windows-1251
catalog_html = open(catalog_url)
catalog_doc  = Nokogiri::HTML(catalog_html)
catalog_doc.encoding = 'UTF-8' # конвертируем 1251 to UTF-8
agent = Mechanize.new
page  = agent.get(catalog_url)
page.encoding = 'UTF-8' # конвертируем 1251 to UTF-8
puts page

output_file = File.open("./catalog.txt", "w")


#def scan_main()
  catalog_doc.css('.children a').each do |string|
    type    = "Group"
    group   = "-----"
    name    = string.to_s.scan(%r{\)">(.*)<span>}m)[0][0] # названия главных категорий с главной страницы сайта
    id      = Digest::MD5.hexdigest(type+group+name)
    picture = string.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
    picture = picture ? picture[0] : '-----------------------------------------'
    $,      = "\t"

    output_file.print id, type, group, picture, name
    output_file.puts
  end
#end


#scan_main()
