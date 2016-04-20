#!/usr/bin/env ruby
# encoding: UTF-8

require 'gnuplot'
require 'pp'

def median_split(arr)
  c = arr.size%2
  subset = [arr[0..arr.size/2-1], arr[arr.size/2+c..-1]]
  m = median arr
  subset[0].push m
  subset[1].unshift m
  subset
end

def median(arr)
  if arr.size.odd?
    arr[arr.size/2]
  else
    (arr[arr.size/2 -1 ].to_f + arr[arr.size/2].to_f) / 2
  end
end

def quartile(arr,n=3)
  arr.sort!
  split = median_split arr
  case n
  when 1
    median split[0]
  when 2
    median arr
  when 3
    median split[1]
  end
end

data = File.readlines("clean-data.csv")

#drop first line
data = data.drop 1

#drop unused challenges
data.reject!{|line| ((line.start_with? 'meteor-contest') || (line.start_with? 'chameneos-redux') || (line.start_with? 'thread-ring')) }

#drop first and second line in every 3
data2 = data.each_slice(3).map(&:last)

Measurement = Struct.new(:time, :code_size, :mem)

# get gcc results for normalizing
tasks = Hash.new
data2.each do |line|
  task,language,id,n,gz,cpu,kb,status,load_string,secs = line.strip.split(/,/)
  next unless language == 'C gcc'
  tasks[task] = Measurement.new(secs.to_f, gz.to_f, kb.to_f)
end

hash = Hash.new
data2.each do |line|
  task,language,id,n,gz,cpu,kb,status,load_string,secs = line.strip.split(/,/)
  if hash[language].nil?
    m = Measurement.new
    m.time = Array.new
    m.code_size = Array.new
    m.mem = Array.new
    hash[language] = m
  end
  #normalize with gcc results
  # if secs.to_f < tasks[task].time
    # puts "#{language}: #{task} #{secs.to_f}sec #{tasks[task].time}sec"
  # end
  hash[language].time.push     (secs.to_f / tasks[task].time)
  hash[language].code_size.push(gz.to_f / tasks[task].code_size)
  hash[language].mem.push(kb.to_f / tasks[task].mem)
end

Stat = Struct.new(:lang, :min, :q1, :median, :q3, :max)

@stat_time = Array.new
stat_mem = Array.new
stat_code = Array.new

hash.each do |lang, m|
  a = m.time.sort
  @stat_time.push(Stat.new(lang, a.min, quartile(a,1), quartile(a,2), quartile(a,3), a.max))
  a = m.code_size.sort
  stat_code.push(Stat.new(lang, a.min, quartile(a,1), quartile(a,2), quartile(a,3), a.max))
  a = m.mem.sort
  stat_mem.push(Stat.new(lang, a.min, quartile(a,1), quartile(a,2), quartile(a,3), a.max))
end

@stat_time.sort_by!(&:median)
stat_mem.sort_by!(&:median)
stat_code.sort_by!(&:median)

@textcolor = "tc rgb 'grey'"

def plot(max)
  filename = ""
  if max.nil?
    filename = "game_overview.png"
  else
    filename = "game_zoomed_in.png"
  end

  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|

      font = '/usr/share/fonts/type1/gsfonts/n019003l.pfb'
      plot.output(filename) 
      plot.terminal("png medium size 960,1800 font \"#{font}\" 9 background rgb 'black'")

      plot.key("left top")
      plot.grid("ytics")
      plot.xtics("rotate scale 0 #{@textcolor}")
      plot.ytics("rotate scale 0 #{@textcolor}")
      plot.bmargin("9")
      plot.border("0")
      plot.style("fill solid")
      plot.arbitrary_lines = ["unset key"]

      data = []
      data.push (1..@stat_time.size).to_a
      data.push @stat_time.collect(&:min)
      data.push @stat_time.collect(&:q1)
      data.push @stat_time.collect(&:median)
      data.push @stat_time.collect(&:q3)
      data.push @stat_time.collect(&:max)
      data.push [0.5] * @stat_time.size
      data.push @stat_time.collect{|x| x.lang.inspect}

      plot.xrange("[0.5:#{@stat_time.size+0.5}]")
      unless max.nil?
        plot.yrange("[0:#{max}]")
      end

      plot.data << Gnuplot::DataSet.new(data) do |ds|
        ds.using = "1:3:2:6:5:7:xticlabels(8)"
        ds.with = "candlesticks lt 3 lw 2 whiskerbars"
        #ds.notitle
      end

      plot.data << Gnuplot::DataSet.new(data) do |ds|
        ds.using = "1:4:4:4:4:7"
        ds.with = "candlesticks lt 7 lw 2"
        # ds.notitle
      end
    end
  end

  `mogrify -rotate 90 #{filename}`
end

plot(nil)
plot(6)

`eom game_zoomed_in.png`
