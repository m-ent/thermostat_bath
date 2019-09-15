require 'sinatra'
require 'sinatra/reloader'
require 'json'

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
        if m = /(.+),\s*(.+)/.match(l)
          @temp, @target = m[1], m[2]
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
    現在温度: <span id="temp"> </span>
    (目標温度: <span id="target"> </span>)
  </p>

  <script type='text/javascript' src='jquery-3.3.1.min.js'></script>

  <script type="text/javascript">
    $(function(){
      function startTimer(){
        timer = setInterval(exec, 1000); // 1000ms毎に exec() を実行する
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
      }
    });

  </script>
</body>
