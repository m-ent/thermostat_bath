class Thermo_controller
  def initialize(temp = 36.0, interval = 10.0, kp = 0.0, ki = 0.0, kd = 0.0)
    @log = false
    @log_file = '/tmp/temp.log'
    @status = true
    @status_file = '/tmp/thermobath_status.dat'
    @direction_file = '/tmp/direction.dat'
    @on_fly = false
    @verbous = false # for debug: show temperature each cycle in console
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

  def on_fly(mode)
    case mode
    when :on
      @on_fly = true
      system("gpioctl -c 18 OUT")
    else
      @on_fly = false
    end
  end

  def call_onewire
    `sysctl dev.ow_temp.0.temperature`
  end

  def get_temp
    case @on_fly
    when true
      ow_temp = 0.0
      until (ow_temp = /.+: (-?\d+\.\d+)/.match(call_onewire))
      end
      1.05 * ow_temp[1].to_f - 2.04
    else
      0.0
    end
    # calibration by data below (retake for device renewal)
    # x:1-wire DS18B20 y:analog thermometer / y = 1.05 x - 2.04
    # 53.437  54
    # 52.25   53
    # 51.062  52
    # 50.25   51
    # 49.187  50
    # 48.187  49
    # 47.312  48
    # 46.5    47
    # 45.562  46
    # 44.562  45
    # 43.687  44
    # 42.687  43
    # 41.937  42
    # 41      41
    # 39.937  40
    # 39.062  39
    # 38      38
    # 37.062  37
    # 36.25   36
    # 35.25   35
    # 34      34
    # 33      33
    # 32.062  32
    # 31.187  31
    # 30.187  30
    # 29.375  29
    # 28.437  28
    # 27.562  27
    # 26.812  26
    # 25.812  25
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
    if @log
      File.open(@log_file, 'a') do |f|
        f.puts "=====\ntarget: #{@target}, interval: #{@interval}, Kp: #{@kp}, Ki: #{@ki}, Kd: #{@kd}"
      end
    end
    if @status
      File.open(@status_file, 'w') do |f|
        f.puts ",,"
      end
    end
    sleep @interval
    loop do
      @idle = false
      if File.exists?(@direction_file)
        File.open(@direction_file) do |f|
          if f.gets =~ /stop/
            @idle = true
            break
          end
        end
      end
      temp1 = get_temp
      loop do
        break if (temp1 - temp0).abs < 2.5 # 外れ値対策
        temp1 = get_temp
      end
      puts temp1 if @verbous
#      temp1 = temp0 if temp1 > temp0 * 1.75
#      temp1 = temp0 if temp1 < temp0 * 0.5
#      puts temp1
      break if condition == :temp and temp1 > ref_value
      if @log
        File.open(@log_file, 'a') do |f|
          f.puts "#{temp1} #{Time.now.strftime("%H%M%S")}" if @log
        end
      end
      put_power(calc_power(temp0, temp1)) if not @idle
      temp0 = temp1
      if @status
        File.open(@status_file, 'w') do |f|
          state = (@idle ? 'idle' : 'going')
          f.puts "#{state},#{temp1.round(1)}, #{@target.round(1)}"
        end
      end
      cycle += 1
      break if condition == :cycle and \
        (cycle >= ref_value and ref_value >= 0)
      break if @idle
    end
    return {temp: temp1, cycle: cycle}
  end
end
