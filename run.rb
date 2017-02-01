require './controller'

temp = ARGV.shift
temp = (38.0 if not temp).to_f

c = Thermo_controller.new(temp * 1.2, 10, 0.098)
c.on_fly(:on)
c.run_until_temp_become( temp / 3 )
sleep 150
c.run_until_temp_become( temp * 2 / 3 )
sleep 150

c = Thermo_controller.new(38, 10, 0.098, 0.000567, 4.234)
c.log(:on)
c.on_fly(:on)
c.start
