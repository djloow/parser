require 'ruby-progressbar'

module Stats
  class << self
    attr_accessor :total, :total_in_group, :current_group, :start
    attr_accessor :wo_pic, :pic_size, :total_size, :progressbar

    def init
      @total = 0.0
      @total_in_group = Hash.new(0.0)
      @current_group = ''
      @start = Time.now
      @wo_pic = 0.0
      @pic_size = Hash.new(0.0)
      @total_size = 0.0
      @progressbar = ProgressBar.create(total: 10_850, format: '%t: |%B| %p%% complete. ')
    end

    def print_stat 
      puts '******************Summary by first 1000 goods******************'
      @total_in_group.each do |group, count|
        pc = (count/@total)*100
        puts "#{group}: #{count} items, #{pc}% of total"
      end

      goods_with_picture = ((@total - @wo_pic) / (@total)*100).round(1)
      puts "Percent goods with pictures: #{goods_with_picture} %"

      top_size = @pic_size.max_by { |pic, size| size }
      puts "Top size image: #{top_size[0]}; size: #{((top_size[1])/1024).round(1)} kB"

      least_size = @pic_size.min_by { |pic, size| size }
      puts "Least size image: #{(least_size[0])}; size: #{((least_size[1])/1024).round(1)} kB"

      average_size = @total_size/1000/1024
      puts "Average image size: #{average_size.round(1)} kB"
    end

  end
end

