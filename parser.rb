require 'open-uri'
require 'nokogiri'
require 'digest'
require 'mechanize'


class Parser

  def initialize

    @catalog_url  = 'http://www.a-yabloko.ru/catalog/' # кодировка страницы windows-1251
    @catalog_html = open(@catalog_url)
    @catalog_doc  = Nokogiri::HTML(@catalog_html)
    @catalog_doc.encoding = 'UTF-8' # конвертируем 1251 to UTF-8

    @agent = Mechanize.new
    @page  = @agent.get(@catalog_url)
    puts @page

    @@output_file = File.open("./catalog.txt", "w")
  end

  def download(pic)
    open('pictures/'+pic, 'wb') do |file|
      file << open('http://www.a-yabloko.ru/storage/catalog/.thumbs/'+pic).read
    end
  end

  # Метод составляет список категорий с главной страницы сайта и загружает соответствующие картинки
  def scan_main
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
    end
  end

  def scan_groups

  end

end

parser = Parser.new
parser.scan_main

parser.scan_groups
