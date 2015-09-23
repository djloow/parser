require 'open-uri'
require 'nokogiri'
require 'digest'
require 'curl'

class Parser

  @@output_file ||= File.open("./catalog.txt", "w")
  @@depth = 0    # глубина рекурсии
  $,      = "\t" # разделитель для print
  @@total = 0    # общее количество записей
  @@total_in_group = Hash.new
  @@current_group = ""

  def initialize(url)
    @catalog_html = Curl.get(url).body_str # скачиваем страницу, она в windows-1251
    @catalog_doc  = Nokogiri::HTML(@catalog_html) # создаём документ
    @catalog_doc.encoding = 'UTF-8' # конвертируем 1251 to UTF-8
  end

  # Все картинки на сервере лежат в одной папке,
  # а значит имеют уникальные имена, их и возьмём.
  def download_gr(pic)
    open('pictures/'+pic, 'wb') do |file|
      file << open('http://www.a-yabloko.ru/storage/catalog/.thumbs/'+pic).read
    end
  end

  def download_item(pic)
    open('pictures/'+pic, 'wb') do |file|
      file << open('http://www.a-yabloko.ru/storage/catalog/goods/.thumbs/'+pic).read
    end
  end

  # Метод составляет список категорий с главной страницы сайта и загружает соответствующие картинки
  def scan_groups
    puts "-Scanning groups..."
    @@depth += 1
    puts "***Depth is #{@@depth}"
    links = scan_footer if @@depth == 1
    if @@depth > 1
      group = @catalog_doc.css('#content.bar h1').text
    else
      group = "---------"
    end
    strings = @catalog_doc.css('.children a')
    strings.each do |string|
      type    = "sub-"*(@@depth-1)+"group"
      name    = string.to_s.scan(%r{\)">(.*)<span>}m)[0][0] # названия главных категорий с главной страницы сайта
      puts name
      @@current_group = name if @@depth == 1
      id      = Digest::MD5.hexdigest(type+group+name)
      picture = string.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
      download_gr(picture[0]) unless picture.nil? # если картинка есть - скачиваем её
      picture = picture ? picture[0] : '-----------------------------------------' # если картинки нет - ставим прочерк
      if @@depth == 1
        parser = Parser.new('http://www.a-yabloko.ru'+links.shift)
      else
        parser = Parser.new('http://www.a-yabloko.ru'+string['href'])  #.to_s.scan(%r{href="(.*)" })[0][0])
      end
      add_record(id, type, group, picture, name)
      parser.scan_groups
    end
    scan_goods if strings.empty?

    @@depth -= 1
  end

  def scan_footer
    puts "--Scanning footer..."
    links = Array.new
    @catalog_doc.css('a.root').each do |string|
      links << string['href']  #.to_s.scan(%r{href="(.*)">})[0][0]
    end
    links
  end

  def scan_goods
    puts "---Scanning goods....."
    group = @catalog_doc.css('#content.bar h1').text
    strings = @catalog_doc.css('div.goods .img')
    strings.each do |string|
      puts string['title']
      type = "Item"
      name = string['title']
      id = Digest::MD5.hexdigest(type+group+name)
      picture = string.to_s.scan(%r{thumbs/(.*)'\)" }m)[0]
      if !picture || picture[0] == 'no_img_w280h140.png'
        picture = '-----------------------------------------'
      else
        picture = picture[0]  # если картинки нет - ставим прочерк
        download_item(picture[0]) # если картинка есть - скачиваем её
      end
      add_record(id, type, group, picture, name)
    end
  end

  def add_record(id, type, group, picture, name)
    @@output_file.print id, type, group, picture, name+"\n"
    @@total += 1
    
  end

  def start
    scan_groups
  end

end

parser = Parser.new('http://www.a-yabloko.ru/catalog')

parser.start

sleep 10
