require 'sinatra'
require 'sinatra/reloader'
require 'json'
require './controller'
set :bind, '0.0.0.0'

target = ARGV.shift
case target
when /\d+\.?\d*/
else
  target = 38.0
end
temp = target.to_f
coefficient = 0.95
resting_time = 30 #[sec]

def rest(t)
  puts "rest for #{t} second."
  sleep t
end

th = Thread.new do # 別スレッドで PID 制御を実行
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
    tt = temp * coefficient ** (i - ii)
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
end

# ここから sinatra の設定: 温度報告用

get '/' do
  erb :index
end

get '/get_status' do
  @stat_file = "/tmp/thermobath_status.dat"
  @temp, @target = '-274.0', '-274.0' # エラー値
  if File.exists?(@stat_file)
    if  (Time.now - File::Stat.new(@stat_file).mtime) < 30 * 60 
      File.open(@stat_file) do |f|
        l = f.gets
        if m = /(.+),\s*(.+),\s*(.+)/.match(l)
          @temp, @target = m[2], m[3]
        end
      end
    end
  end
  {temp: @temp, target: @target}.to_json
end

__END__

@@index
<head> <title>Thermostat bath status report</title> </head>
<body>
  <p>
    現在温度: <span id="temp"> </span> ℃
    (目標温度: <span id="target"> </span> ℃): @<span id="time"> </span>
  </p>

  <script type='text/javascript' src='jquery-3.3.1.min.js'></script>

  <script type="text/javascript">
    $(function(){
      function startTimer(){
        timer = setInterval(exec, 5000); // 5000ms毎に exec() を実行する
      }                                  // その情報をtimer変数へ入れている。

      startTimer(); //タイマー開始

      function exec(){
        $.ajax({
          type: "GET",
          url: "/get_status",
          dataType: "json",
          success: function(json) {
            $('#temp').text(json.temp);
            $('#target').text(json.target);
          },
          error: function() {
            $('#temp').text('---');
            $('#target').text('---');
          }
        });
        $('#time').text((new Date()).getHours() + ":" + (new Date()).getMinutes() + ":" + (new Date()).getSeconds());
      }
    });

  </script>
</body>
