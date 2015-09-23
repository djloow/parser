require 'open-uri'
require 'nokogiri'
require 'digest'
require 'curl'

class Parser

  @@output_file ||= File.open("./catalog.txt", "w")
  @@depth = 0
  $,      = "\t" # разделитель для print

  def initialize(url)
    @catalog_html = Curl.get(url).body_str
    @catalog_doc  = Nokogiri::HTML(@catalog_html)
    @catalog_doc.encoding = 'UTF-8' # конвертируем 1251 to UTF-8
    #puts @catalog_html
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
    puts "-Scanning groups..."
    @@depth += 1
    puts "***Depth is #{@@depth}"
    links = scan_footer if @@depth == 1
    strings = @catalog_doc.css('.children a')
    strings.each do |string|
      type    = "sub-"*(@@depth-1)+"Group"
      group   = "-----"
      name    = string.to_s.scan(%r{\)">(.*)<span>}m)[0][0] # названия главных категорий с главной страницы сайта
      puts name
      id      = Digest::MD5.hexdigest(type+group+name)
      picture = string.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
      #download(picture[0]) unless picture.nil? # если картинка есть - скачиваем её
      picture = picture ? picture[0] : '-----------------------------------------' # если картинки нет - ставим прочерк
      @@output_file.print id, type, group, picture, name+"\n"
      if @@depth == 1
        parser = Parser.new('http://www.a-yabloko.ru'+links.shift)
      else
        parser = Parser.new('http://www.a-yabloko.ru'+string.to_s.scan(%r{href="(.*)" })[0][0])
      end
      parser.scan_groups
    end
    scan_goods if strings.empty?

    @@depth -= 1
  end

  def scan_footer
    puts "--Scanning footer..."
    links = Array.new
    @catalog_doc.css('a.root').each do |string|
      links << string.to_s.scan(%r{href="(.*)">})[0][0]
    end
    links
  end

  def scan_goods
    puts "---Scanning goods....."
  end

end

parser = Parser.new('http://www.a-yabloko.ru/catalog')

parser.scan_groups
