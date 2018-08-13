require 'sinatra'
require 'sinatra/reloader'
require 'json'
require './controller'

th = Thread.new do
  # thermobath controller settings here
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
      @status, @temp, @target = 'error', 'error' 'error'
    end
  end
  {status: @status, temp: @temp, target: @target}.to_json
end

__END__

@@index
<head> <title>Thermostat bath controller</title> </head>
<body>
  <p class="radio_area">稼動状態: 
    <input type="radio" name="state" value="1" checked="checked">稼働
    <input type="radio" name="state" value="0">停止
  <input id="change_state_btn" type="button" value="変更">
  </p>
  <p id="report_place"> </p>

  <script type='text/javascript' src='jquery-3.3.1.min.js'></script>

  <script type="text/javascript">
    $(function(){
      function startTimer(){
        timer = setInterval(exec, 2000); // 2000ms毎に exec() を実行する
      }                                  // その情報をtimer変数へ入れている。

      startTimer(); //タイマー開始

      function exec(){
        $.ajax({
          type: "GET",
          url: "/get_status",
          dataType: "json",
          success: function(json) {
            // some_procedures;
            //$('#report_place').text(json.element);
          },
          error: function() {
            // error_handling;
          }
        });
      }

      $("#change_state_btn").click(function(){
        var change_val = $('input[name=state]:checked').val();
        console.log(change_val); //=>0

        $.post('/post', {state: change_val})

        // some_procedures;
      });
    });

  </script>
</body>
