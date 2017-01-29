require './main'

c = Thermo_controller.new
c.on_fly(:on)
puts c.get_temp
