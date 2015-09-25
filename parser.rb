require 'open-uri'
require 'csv'
require 'nokogiri'
require 'digest'
require 'curl'

class Parser

  @@headers = %w{id, type, group, pic, name}
  @@catalog  ||= CSV.read("catalog.txt", "a+", col_sep: "\t", headers: true, converters: :numeric, :header_converters => :symbol).map { |row| row.to_h }
  @@depth          = 0    # глубина рекурсии
  @@col_sep        = "\t" # разделитель для print
  @@total          = 0    # общее количество записей
  @@total_in_group = Hash.new(0)
  @@current_group  = ""
  @@start          = Time.now

  def initialize(url)
    @catalog_html = Curl.get(url).body_str # скачиваем страницу, она в windows-1251
    @catalog_doc  = Nokogiri::HTML(@catalog_html) # создаём документ
    @catalog_doc.encoding = 'UTF-8' # конвертируем 1251 to UTF-8
  end

  # Все картинки на сервере лежат в одной папке,
  # а значит имеют уникальные имена, их и возьмём.
  def download_group(pic)
    open('pictures/'+pic, 'wb') do |file|
      file << open('http://www.a-yabloko.ru/storage/catalog/.thumbs/'+pic).read
    end
  end

  # Ладно, не в одной, а в двух папках.
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
    group = @catalog_doc.css('#content.bar h1').text
    rows = @catalog_doc.css('.children a')
    rows.each do |row|
      type    = "sub-"*(@@depth-1)+"group"
      name    = row.to_s.scan(%r{\)">(.*)<span>}m)[0][0] # названия главных категорий с главной страницы сайта
      puts name
      id      = Digest::MD5.hexdigest(type+group+name)
      picture = row.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
      download_group(picture[0]) unless picture.nil? # если картинка есть - скачиваем её
      picture = picture ? picture[0] : '-----------------------------------------' # если картинки нет - ставим прочерк
      parser = Parser.new('http://www.a-yabloko.ru'+row['href'])
      add_record([id, type, group, picture, name])
      parser.scan_groups
    end
    #scan_goods if rows.empty?

    @@depth -= 1
  end

  def scan_main
    puts "Scanning main page..."
    links = scan_footer
    group = "---------"
    rows = @catalog_doc.css('.children a')
    rows.each do |row|
      type    = "group"
      name    = row.to_s.scan(%r{\)">(.*)<span>}m)[0][0] # названия главных категорий с главной страницы сайта
      puts name
      @@current_group = name
      id      = Digest::MD5.hexdigest(type+group+name)
      picture = row.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
      download_group(picture[0]) unless picture.nil? # если картинка есть - скачиваем её
      picture = picture ? picture[0] : '-----------------------------------------' # если картинки нет - ставим прочерк
      parser = Parser.new('http://www.a-yabloko.ru'+links.shift)
      add_record([id, type, group, picture, name])
      parser.scan_groups
    end
  end

  def scan_footer
    puts "--Scanning footer..."
    links = Array.new
    @catalog_doc.css('a.root').each do |row|
      links << row['href']
    end
    links
  end

  def scan_goods
    puts "---Scanning goods....."
    group = @catalog_doc.css('#content.bar h1').text
    rows = @catalog_doc.css('div.goods .img')
    rows.each do |row|
      type = "Item"
      name = row['title']
      id = Digest::MD5.hexdigest(type+group+name)
      picture = row.to_s.scan(%r{thumbs/(.*)'\)" }m)[0]
      if !picture || picture[0] == 'no_img_w280h140.png'
        picture = '-----------------------------------------'
      else
        picture = picture[0]  # если картинки нет - ставим прочерк
        download_item(picture[0]) # если картинка есть - скачиваем её
      end
      add_record([id, type, group, picture, name])
    end
  end

  def add_record(arr)
    @@catalog << arr
    @@total += 1
  end

  def save
    @@catalog.uniq!
    CSV.open("catalog.txt", "w", col_sep: "\t", encoding: 'UTF-8', headers: true) do |cat|
      @@catalog.each do |row|
        cat << row
      end
    end
  end

  def start
    add_record(@@headers)
    scan_main
    save
    puts Time.now - @@start
  end

end

parser = Parser.new('http://www.a-yabloko.ru/catalog')

parser.start

sleep 10
