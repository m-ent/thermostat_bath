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

def get_state
  File.open('/tmp/direction.dat') do |f|
    f.gets.chomp
  end
end

def rest(t)
  return if get_state == 'stop'
  puts "rest for #{t} second."
  sleep t
end

th = Thread.new do # 別スレッドで PID 制御を実行
  loop do
    case get_state
    when 'stop'
      # do nothing
    else
      temp = d if /^\d+\.?\d*$/.match(d)
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
  end
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
          @state, @temp, @target = m[1], m[2], m[3]
        end
      end
    end
  end
  {state: @state, temp: @temp, target: @target}.to_json
end

put '/set_direction/:state' do
  #  params = {"target"=>"38.0", "state"=>"run"}
  #  params = {"state"=>"stop"}
  @direction_file = '/tmp/direction.dat'
  case params['state']
  when 'stop'
    direction = "stop"
  when 'run'
    direction = params['target']
  end
  File.open(@direction_file, 'w') do |f|
    f.puts(direction)
  end
end

__END__

@@index
<head> <title>Thermostat bath status report</title> </head>
<body>
  <p>
  [Console]</br>
    <input id="run_btn" type="button" value="保温">
    <input id="target_temp" type="text" size="4" value="38.0">℃    |  
    <input id="stop_btn" type="button" value="停止">
  <p>
  [Status]</br>
    状態: <span id="state"> </span> 
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
            if (json.state == "going") {
              $('#state').text("稼働中");
              $('#temp').text(json.temp);
              $('#target').text(json.target);
            } else {
              $('#state').text("休止中");
              $('#temp').text("---");
              $('#target').text("---");
            }
          },
          error: function() {
            $('#temp').text('---');
            $('#target').text('---');
          }
        });
        $('#time').text((new Date()).getHours() + ":" + (new Date()).getMinutes() + ":" + (new Date()).getSeconds());
      }
    });

    $("#run_btn").click(function(){
      var target_val = $("#target_temp").val();
      if (target_val.search(/^\d+\.?\d*$/) == -1){
          target_val = "38.0"
      }
      $("#target_temp").val(target_val);
      send_data = "target=" + target_val;
      $.ajax({
        url: '/set_direction/run',
        type: 'PUT',
        data: send_data
      });
    });

    $("#stop_btn").click(function(){
      $.ajax({
        url: '/set_direction/stop',
        type: 'PUT',
      });
    });

  </script>
</body>
