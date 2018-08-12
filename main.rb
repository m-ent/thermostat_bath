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

__END__

@@index
<body>
  <input id="undefined_btn" type="button" value="click">
  <p id="report_place"> </p>

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
            // some_procedures;
            //$('#report_place').text(json.element);
          },
          error: function() {
            // error_handling;
          }
        });
      }

      $("#undefined_btn").click(function(){
        // some_procedures;
      });
    });

  </script>
</body>
