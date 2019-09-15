ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/reporters'
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
require 'rack/test'
require './main'

include Rack::Test::Methods

def app
  Sinatra::Application
end

describe "Thermobath controller UI" do
  describe "GET /" do
    it "response 200 を返すこと" do
      get '/'
      last_response.ok?.must_equal true
    end
  end

  describe "GET /get_status" do
    before do
      @stat_file = "/tmp/thermobath_stat.dat"
      @status = (rand < 0.5)? "going" : "idle"
      @temp = 30.0 + rand(10)
      File.open(@stat_file, 'w') do |f|
        f.puts "#{@status}, #{@temp}, 36.0"
      end
      get '/get_status'
      @response = last_response
    end

    it "response 200 を返すこと" do
      @response.ok?.must_equal true
    end

     it "稼働状況を json で返すこと" do
      res = JSON.parse(@response.body)
      res.has_key?('status').must_equal true
      res['status'].must_equal @status
    end

     it "現在の温度を json で返すこと" do
      res = JSON.parse(@response.body)
      res.has_key?('temp').must_equal true
      res['temp'].to_f.must_equal @temp.to_f
    end

    after do
      File.delete(@stat_file) if File.exists?(@stat_file)
    end
  end

  describe "PUT /set_direction" do
    before do
      @direction_file = '/tmp/direction.dat'
    end

    it "direction を stop から go に変更できる" do
      File.open(@direction_file, 'w') do |f|
        f.puts "stop"
      end
      put '/set_direction/go'
      last_response.ok?.must_equal true # response 200 を返すこと
      File.open(@direction_file) do |f|
        f.gets.chomp.must_match /^go/
      end
    end

    it "direction を go から stop に変更できる" do
      File.open(@direction_file, 'w') do |f|
        f.puts "go"
      end
      put '/set_direction/stop'
      last_response.ok?.must_equal true # response 200 を返すこと
      File.open(@direction_file) do |f|
        f.gets.chomp.must_match /^stop/
      end
    end
  end
end
