require 'open-uri'
require 'nokogiri'
require 'digest'
require 'curl'


class Parser

  @@output_file = File.open("./catalog.txt", "w")

  def initialize(url)
    @catalog_url  = url # кодировка страницы windows-1251
    @catalog_html = Curl.get(@catalog_url).body_str
    @catalog_doc  = Nokogiri::HTML(@catalog_html)
    @catalog_doc.encoding = 'UTF-8' # конвертируем 1251 to UTF-8
    puts @catalog_doc
  end

  # Все картинки на сервере лежат в одной папке,
  # а значит имеют уникальные имена, их и возьмём.
  def download(pic)
    open('pictures/'+pic, 'wb') do |file|
      file << open('http://www.a-yabloko.ru/storage/catalog/.thumbs/'+pic).read
    end
  end

  # Метод составляет список категорий с главной страницы сайта и загружает соответствующие картинки
  def scan_groups
    #puts @catalog_doc.css('.children a')[0]
    @catalog_doc.css('.children a').each do |string|
      type    = "Group"
      group   = "-----"
      name    = string.to_s.scan(%r{\)">(.*)<span>}m)[0][0] # названия главных категорий с главной страницы сайта
      id      = Digest::MD5.hexdigest(type+group+name)
      picture = string.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
      download(picture[0]) unless picture.nil? # если картинка есть - скачиваем её
      picture = picture ? picture[0] : '-----------------------------------------' # если картинки нет - ставим прочерк
      $,      = "\t" # разделитель для print
      @@output_file.print id, type, group, picture, name
      @@output_file.puts
      link = string.to_s.scan(%r{href="(.*)" style})
      puts link
      #parser = Parser.new(link)
    end
  end

  def scan_goods

  end

end

parser = Parser.new('http://www.a-yabloko.ru/catalog')

parser.scan_groups
