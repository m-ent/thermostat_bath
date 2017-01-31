# PID tuning using step response
# https://ja.wikipedia.org/wiki/PID%E5%88%B6%E5%BE%A1
require './controller'

temps = Array.new
highest = 0.0
highest_point = 0
target_point = 0
interval = 10.0
c = Thermo_controller.new(90.0, interval, 10.0)
c.on_fly(:on)

def p_on
  system("gpioctl 18 1")
end

def p_off
  system("gpioctl 18 0")
end

i = 0
p_on
loop do
  puts (t = c.get_temp)
  temps << t
  if t > highest
    highest = t
    highest_point = i
  end
  break if (t < (highest - 2) and target_point != 0)
  if t < 38.0
    target_point = i
  else
    p_off
  end
  sleep interval
  i += 1
end
target_point += 1

d_max = 0.0
d_max_point = 0
(0..temps.length-2).each do |i|
  d = temps[i+1] - temps [i] 
  if d > d_max
    d_max = d
    d_max = i
  end
end

r = d_max / interval  # 最大傾斜
l = interval * d_max_point - (temps[i] - temps[0]) / r 

File.open("./step_response_#{`date`.chomp}.csv", 'w') do |f|
  f.puts "Result: R: #{r}, L: #{l}"
  temps.each do |t|
    f.puts t
  end
end

puts "Result:"
puts " R: #{r}"
puts " L: #{l}"
