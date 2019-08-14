require './controller'

temp = (ARGV.shift || "38.0").to_f
coefficient = 0.95
resting_time = 30 #[sec]

def rest(t)
  puts "rest for #{t} second."
  sleep t
end

c = Thermo_controller.new(temp, 10, 0.098, 0.000567, 4.234)
c.on_fly(:on)
t0 = c.get_temp
t0 = 0.1 if t0 <= 0
puts "start: #{t0} to #{temp} [degree]."
puts "----------------"
t = t0
i = 0
while t < temp * coefficient do
  i += 1
  t /= coefficient
end 

puts "step = #{i}"
skip_last_step = false

i.times do |ii|
  tt = temp * coefficient ** (i -ii)
  puts "go to #{tt} degree"
  c = Thermo_controller.new(tt, 10, 0.098, 0.000567, 4.234)
  c.log(:on)
  c.on_fly(:on)
  if c.get_temp / tt > 0.95
    puts "skiping"
    skip_last_step = true
    next
  end
  skip_last_step = false
  c.run_until_temp_become(tt)
  rest(resting_time)
end

rest(resting_time) if skip_last_step
puts "now, start the maintainance cycle."
c = Thermo_controller.new(temp, 10, 0.098, 0.000567, 4.234)
c.log(:on)
c.on_fly(:on)
c.start
