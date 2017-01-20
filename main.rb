class Thermo_controller
  def initialize(temp = 36.0, interval = 10.0, kp = 0.0, ki = 0.0, kd = 0.0)
    @log = false
    @log_file = 'temp.log'
    @target = temp
    @interval = interval # 測定間隔
    @kp = kp # Kp: 比例制御係数
    @ki = ki # Ki: 積分制御係数
    @i_data = 0.0 # 積分値
    @kd = kd # Kd: 微分制御係数
#    system("gpioctl -c 18 OUT")
  end

  def log(mode)
    case mode
    when :on
      @log = true
    when :on
      @log = false
    end
  end

  def get_temp
    /.+: (\d+\.\d+)/.match(`sysctl dev.ow.temp.0.temperature`)[1]
  end

  def calc_power(temp0, temp1)
    p = @kp * (@target - temp1)/@target
    @i_data += @interval * ((@target - temp0) + (@target - temp1))/2
    i = @ki * @i_data
    d = @kd * (temp0 - temp1) / @interval
      # d(@temp-t)/dt = ((@temp - t1) - (@temp - t0)) / @interval
      #               = (-t1 + t0) / @interval 
#    puts "P: #{p}, I: #{i}, D: #{d}:: total: #{p+i+d}"
    return (p + i + d)
  end 

  def power(state, time)
    case state
    when :on
#      system("gpioctl 18 1")
    when :off
#      system("gpioctl 18 0")
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
    temp0 = get_temp
    sleep @interval
    if @log
      File.open(@log_file, 'w') do |f|
        f.puts "target: #{@target}, interval: #{@interval}, Kp: #{@kp}, Ki: #{@ki}, Kd: #{@kd}"
      end
    end
    loop do
      temp1 = get_temp
      puts temp1
      if @log
        File.open(@log_file, 'a') do |f|
          f.puts temp1 if @log
        end
      end
      put_power(calc_power(temp0, temp1))
      temp0 = temp1
      cycle = (cycle < 0 ? -1 : cycle - 1)
      break if cycle == 0
    end
  end
end
