class Thermo_controller
  def initialize(temp = 36.0, interval = 10.0, kp = 0.0, ki = 0.0, kd = 0.0)
    @log = false
    @log_file = 'temp.log'
    @status = false
    @status_file = ''
    @direction_file = './direction.dat'
    @on_fly = false
    @target = temp
    @interval = interval # 測定間隔
    @kp = kp # Kp: 比例制御係数
    @ki = ki # Ki: 積分制御係数
    @i_data = 0.0 # 積分値
    @kd = kd # Kd: 微分制御係数
  end

  def log(mode)
    case mode
    when :on
      @log = true
    else
      @log = false
    end
  end

  def status_file(status_file)
    @status = true
    @status_file = status_file
  end

  def on_fly(mode)
    case mode
    when :on
      @on_fly = true
      system("gpioctl -c 18 OUT")
    else
      @on_fly = false
    end
  end

  def get_temp
    case @on_fly
    when true
      /.+: (\d+\.\d+)/.match(`sysctl dev.ow_temp.0.temperature`)[1].to_f
    else
      0.0
    end
  end

  def calc_power(temp0, temp1)
    p = @kp * (@target - temp1)
    @i_data += @interval * ((@target - temp0) + (@target - temp1))/2
    i = @ki * @i_data
    d = @kd * (temp0 - temp1) / @interval
      # d(@temp-t)/dt = ((@temp - t1) - (@temp - t0)) / @interval
      #               = (-t1 + t0) / @interval 
#    puts "P: #{p}, I: #{i}, D: #{d}:: total: #{p+i+d}"
    return temp1 < @target ? (p + i + d) : 0
  end 

  def power(state, time)
    case state
    when :on
      system("gpioctl 18 1") if @on_fly
    when :off
      system("gpioctl 18 0") if @on_fly
    end
    sleep time
  end

  def put_power(power)
    power = 1.0 if power > 1.0
    power = 0.0 if power < 0.0
    t = (@interval * power).round
    power(:on, t)
    power(:off, @interval - t)
  end

  def start(cycle = -1)
    self.exec({condition: :cycle, ref_value: cycle})
  end

  def run_until_temp_become(temp)
    self.exec({condition: :temp, ref_value: temp})
  end

  def exec(setting)
    condition = setting[:condition]
    ref_value = setting[:ref_value]
    temp0 = get_temp
    temp1 = 0.0
    cycle = 0
    Dir.glob('/tmp/thermobath_*') do |f|
      File.delete(f)
    end
    sleep @interval
    if @log
      File.open(@log_file, 'w') do |f|
        f.puts "target: #{@target}, interval: #{@interval}, Kp: #{@kp}, Ki: #{@ki}, Kd: #{@kd}"
      end
    end
    loop do
      @idle = false
      if File.exists?(@direction_file)
        File.open(@direction_file) do |f|
          if f.gets =~ /stop/
            @idle = true
          end
        end
      end
      temp1 = get_temp
#      temp1 = temp0 if temp1 > temp0 * 1.75
#      temp1 = temp0 if temp1 < temp0 * 0.5
#      puts temp1
      break if condition == :temp and temp1 > ref_value
      if @log
        File.open(@log_file, 'a') do |f|
          f.puts temp1 if @log
        end
      end
      put_power(calc_power(temp0, temp1)) if not @idle
      temp0 = temp1
      if @status
        File.open(@status_file, 'w') do |f|
          state = (@idle ? 'idle' : 'going')
          f.puts "#{state}, #{temp1}, #{@target}"
        end
      end
      cycle += 1
      break if condition == :cycle and \
        (cycle >= ref_value and ref_value >= 0)
    end
    return {temp: temp1, cycle: cycle}
  end
end
