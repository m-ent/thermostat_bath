require 'sinatra'
require 'sinatra/reloader'
require 'json'
require './controller'

Target = 38.0

th = Thread.new do
  c = Thermo_controller.new(Target, 10, 0.098)
#  c.on_fly(:on)
  c.run_until_temp_become(Target * 0.5)
  sleep 150
  c.run_until_temp_become(Target * 0.75)
  sleep 150

  c = Thermo_controller.new(Target, 10, 0.098, 0.000567, 4.234)
  c.log(:on)
#  c.on_fly(:on)
  c.start
end

get '/' do
  erb :index
end

get '/get_status' do
  @stat_file = "/tmp/thermobath_stat.dat"
  File.open(@stat_file) do |f|
    l = f.gets
    if m = /(.+),\w*(.+),\w*(.+)/.match(l)
      @status, @temp, @target = m[1], m[2], m[3]
    else
      @status, @temp, @target = 'error', 'error', 'error'
    end
  end
  {status: @status, temp: @temp, target: @target}.to_json
end

put '/set_direction/:state' do
  @direction_file = '/tmp/direction.dat'
  case params['state']
  when 'stop'
    direction = "stop"
  else
    direction = "go"
  end
  File.open(@direction_file, 'w') do |f|
    f.puts(direction) 
  end
end

__END__

@@index
<head> <title>Thermostat bath controller</title> </head>
<body>
  <p>
    稼動状態: <span id="status"> </span>
    / 温度: <span id="temp"> </span>
    / 目標温度: <span id="target"> </span>
  </p>
  <p class="radio_area">状態変更: 
    <input type="radio" name="state" value="1" checked="checked">稼働
    <input type="radio" name="state" value="0">停止
  <input id="change_state_btn" type="button" value="変更">
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
            $('#status').text(json.status);
            $('#temp').text(json.temp);
            $('#target').text(json.target);
            if (json.status == 'going'){
              $("input[name='state']").val(["1"]);
            } else {
              $("input[name='state']").val(["0"]);
            };
          },
          error: function() {
            $('#status').text('Error');
            $('#temp').text('---');
            $('#target').text('---');
          }
        });
      }

      $("#change_state_btn").click(function(){
        var change_val = $('input[name=state]:checked').val();
        console.log(change_val); //=>0
        if (change_val == 0){
          $.ajax({
            url: '/set_direction/stop',
            type: 'PUT',
          });
        } else {
          $.ajax({
            url: '/set_direction/go',
            type: 'PUT',
          });
        }
      });
    });

  </script>
</body>
