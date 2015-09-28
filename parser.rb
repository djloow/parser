require 'open-uri'
require 'csv'
require 'nokogiri'
require 'digest'

class Parser

  @@headers        ||= %w{type, group, pic, name}
  @@catalog        ||= CSV.read("catalog.txt", "a+", col_sep: "\t", headers: true, converters: :numeric, header_converters: :symbol).map { |row| row.to_h }
  @@depth          ||= 0    # глубина рекурсии
  @@col_sep        ||= "\t" # разделитель для print
  @@total          ||= 0    # общее количество записей
  @@total_in_group ||= Hash.new(0)
  @@current_group  ||= ""
  @@start          ||= Time.now
  @@wo_pic         ||= 0
  @@pic_size       ||= Hash.new(0)
  @@total_size     ||= 0
  def initialize(url)
    @catalog_html = open(url, "Cookie" => "pgs=500") # скачиваем страницу, она в windows-1251
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
    #puts "***Depth is #{@@depth}"
    group = @catalog_doc.css('#content.bar h1').text
    rows = @catalog_doc.css('.children a')
    rows.each do |row|
      type    = "sub-"*(@@depth-1)+"group"
      name    = row.to_s.scan(%r{\)">(.*)<span>}m)[0][0] # названия главных категорий с главной страницы сайта
      puts name
      #id      = Digest::MD5.hexdigest(type+group+name)
      picture = row.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
      #download_group(picture[0]) unless picture.nil? # если картинка есть - скачиваем её
      picture = picture ? picture[0] : '-----------------------------------------' # если картинки нет - ставим прочерк
      parser = Parser.new('http://www.a-yabloko.ru'+row['href'])
      add_record([type, group, picture, name])
      parser.scan_groups
    end
    scan_goods if rows.empty?

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
      #id      = Digest::MD5.hexdigest(type+group+name)
      picture = row.to_s.scan(%r{thumbs/(.*)\)">}m)[0]
      download_group(picture[0]) unless picture.nil? # если картинка есть - скачиваем её
      picture = picture ? picture[0] : '-----------------------------------------' # если картинки нет - ставим прочерк
      parser = Parser.new('http://www.a-yabloko.ru'+links.shift)
      add_record([type, group, picture, name])
      parser.scan_groups
    end
  end

  # Наличие этого метода само со себе является костылём,
  # спасающим от непонятного бага с кривым скачиванием страницы
  # методом open (да и любым другим методом, пробовал curl и curb - 
  # всё одинаково). Суть проблемы в том, что при скачивании страницы 
  # теряются ссылки на группы - кнопка остаётся, сама ссылка тоже остаётся,
  # но затирается конец ссылки, всё что после последнего слеша.
  # Этот метод выцепляет все эти ссылки из футера страницы.
  # Но оказалось, что там есть две устаревшие ссылки,
  # которые нужно бы исключить из результата:
  # /catalog/340/
  # /catalog/343/
  # 
  def scan_footer
    puts "--Scanning footer..."
    links = Array.new
    @catalog_doc.css('a.root').each do |row|
      links << row['href']
    end
    bad_links = ["/catalog/340/", "/catalog/343/"]
    links -= bad_links
    puts links.size
    links
  end

  def scan_goods
    puts "---Scanning goods....."
    group = @catalog_doc.css('#content.bar h1').text
    rows = @catalog_doc.css('div.goods .img')
    rows.each do |row|
      type = "Item"
      name = row['title']
      #id = Digest::MD5.hexdigest(type+group+name)
      picture = row.to_s.scan(%r{thumbs/(.*)'\)" }m)[0]
      if picture.nil? || picture[0] == 'no_img_w280h140.png'
        # если картинки нет - ставим прочерк
        picture = '-----------------------------------------'
        @@wo_pic += 1
      else
        picture = picture[0]
        download_item(picture) # если картинка есть - скачиваем её
        # Картинка ещё не скачалась, но файл уже занимает её
        # точный размер.
        @@pic_size[picture] = File.size("pictures/"+picture)
        @@total_size += @@pic_size[picture]
      end
      add_record([type, group, picture, name])
      @@total += 1
      @@total_in_group[@@current_group] += 1
    end
  end

  def add_record(arr)
    @@catalog << arr
    print_stat if @@total == 1000
  end

  def print_stat 
    @@total_in_group.each do |group, count|
      pc = count/@@total.to_f
      puts "#{group}: #{count} items, #{pc}% of total"
    end
    puts "Percent goods with pictures: " + (100*(@@total - @@wo_pic) / (@@total.to_f)).round(1).to_s + "%"
    top_size = @@pic_size.max_by { |pic, size| size }
    puts "Top size image: " + (top_size[0]).to_s + "; size: " + ((top_size[1].to_f)/1024).round(1).to_s + " kB"
    least_size = @@pic_size.min_by { |pic, size| size }
    puts "Least size image: " + (least_size[0]).to_s + "; size: " + ((least_size[1].to_f)/1024).round(1).to_s + " kB"
    average_size = (@@total_size.to_f)/1000/1024
    puts "Average image size: " + average_size.round(1).to_s + " kB"
  end

  def save
    @@catalog.uniq!.compact!
    open("tmp.txt", "w")  { |file| file.puts @@catalog }
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
    puts "Time spent: ", Time.now - @@start
    puts "Total goods: ", @@total
  end

end

parser = Parser.new('http://www.a-yabloko.ru/catalog')

parser.start

sleep 10
