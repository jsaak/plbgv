#!/usr/bin/env ruby
# encoding: UTF-8

require 'gnuplot'
require 'pp'

data = File.readlines("clean-data.csv")

#drop first line
data = data.drop 1

#meteor-contest has only 1 result line per language
single_data = data.select{|line| line.start_with? 'meteor-contest'}
multiple_data = data.reject{|line| line.start_with? 'meteor-contest'}

#drop first and second line in every 3 on multiple_data
multiple_data = multiple_data.each_slice(3).map(&:last)

data2 = single_data + multiple_data

Measurement = Struct.new(:time, :code_size, :mem_usage)

# get gcc results for normalizing
tasks = Hash.new
data2.each do |line|
  task,language,id,n,gz,cpu,kb,status,load_string,secs = line.strip.split(/,/)
  pp language
  next unless language == 'C gcc'
  tasks[task] = Measurement.new(secs.to_f, gz.to_f, kb.to_f)
end

# update mem usage on meteor-contest, not to divide by 0
tasks['meteor-contest'].mem_usage = 0.0001

hash = Hash.new
data2.each do |line|
  task,language,id,n,gz,cpu,kb,status,load_string,secs = line.strip.split(/,/)
  if hash[language].nil?
    m = Measurement.new
    m.time = Array.new
    m.code_size = Array.new
    m.mem_usage = Array.new
    hash[language] = m
  end
  #normalize with gcc results
  hash[language].time.push     (secs.to_f / tasks[task].time)
  hash[language].code_size.push(gz.to_f / tasks[task].code_size)
  hash[language].mem_usage.push(kb.to_f / tasks[task].mem_usage)
end

pp hash


exit

Gnuplot.open do |gp|
   Gnuplot::Plot.new(gp) do |plot|

      # font = '/usr/share/fonts/truetype/freefont/FreeMono.ttf'
      font = '/usr/share/fonts/type1/gsfonts/n019003l.pfb'
      # font = '/usr/share/fonts/truetype/windowsbol/tahomabd.ttf'
      # font = '/usr/share/fonts/truetype/msttcorefonts/Courier_New_Bold.ttf'
      plot.terminal("png medium size 1000,600 x000000 x777777 x404040 xff0000 xffa500 x66cdaa xcdb5cd xadd8e6 x0000ff xdda0dd x9500d3 font \"#{font}\" 9")
      plot.output("poker.png") 

      plot.key("left top")
      plot.grid("ytics")
      plot.title("updated: #{Time.now}")
      plot.xzeroaxis("lt -1")
      plot.pointsize("0")
      # plot.ylabel('ft')
      # plot.xlabel('jatekok')
      #plot.xgrid(data[0])

      dss = Array.new
      cols.each do |c|
         x = 0
         ds = Gnuplot::DataSet.new( data[c] ) do |ds|
            x += 1
            # ds.with = "linespoints pt 13"
            ds.with = "linespoints"
            ds.title = names[c]
         end
         dss.push(ds)
      end

      plot.data = dss
   end
end