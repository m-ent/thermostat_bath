ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/reporters'
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
require 'rack/test'
require './reporter'

include Rack::Test::Methods

def app
  Sinatra::Application
end

describe "Thermobath reporter" do
  describe "GET /" do
    it "response 200 を返すこと" do
      get '/'
      last_response.ok?.must_equal true
    end
  end

  describe "GET /get_status" do
    describe "正しい stat file がある場合" do
      before do
        @stat_file = "/tmp/thermobath_status.dat"
        @temp = 30.0 + rand(100) / 10.0
        File.open(@stat_file, 'w') do |f|
          f.puts "#{@temp}, 36.0" # temperature, target temp
        end
        get '/get_status'
        @response = last_response
      end

      it "response 200 を返すこと" do
        @response.ok?.must_equal true
      end

       it "現在の温度を json で返すこと" do
        res = JSON.parse(@response.body)
        res.has_key?('temp').must_equal true
        res['temp'].to_f.must_equal @temp
      end

      it "目標温度を json で返すこと" do
        res = JSON.parse(@response.body)
        res.has_key?('target').must_equal true
        res['target'].to_f.must_equal 36.0
      end

      after do
        File.delete(@stat_file) if File.exists?(@stat_file)
      end
    end

    describe "stat file がない場合" do
      before do
        @stat_file = "/tmp/thermobath_status.dat"
        File.delete(@stat_file) if File.exists?(@stat_file)
        get '/get_status'
        @response = last_response
      end

      it "response 200 を返すこと" do
        @response.ok?.must_equal true
      end

     it "現在の温度として json で -274.0 を返すこと" do
        res = JSON.parse(@response.body)
        res.has_key?('temp').must_equal true
        res['temp'].to_f.must_equal -274.0
      end

      it "目標温度として json で -274.0 を返すこと" do
        res = JSON.parse(@response.body)
        res.has_key?('target').must_equal true
        res['target'].to_f.must_equal -274.0
      end
    end

    describe "古い stat file がある場合" do
      before do
        @stat_file = "/tmp/thermobath_status.dat"
        @temp = 30.0 + rand(100) / 10.0
        File.open(@stat_file, 'w') do |f|
          f.puts "#{@temp}, 36.0" # temperature, target temp
        end
      end

      describe "タイムスタンプが30分以上前の場合" do
        before do
          File.utime(Time.now - 31 * 60, Time.now - 31 * 60, @stat_file)
          get '/get_status'
          @response = last_response
        end

        it "response 200 を返すこと" do
          @response.ok?.must_equal true
        end

        it "現在の温度として json で -274.0 を返すこと" do
          res = JSON.parse(@response.body)
          res.has_key?('temp').must_equal true
          res['temp'].to_f.must_equal -274.0
        end

        it "目標温度として json で -274.0 を返すこと" do
          res = JSON.parse(@response.body)
          res.has_key?('target').must_equal true
          res['target'].to_f.must_equal -274.0
        end
      end

      describe "タイムスタンプが30分以上前ではない場合" do
        before do
          File.utime(Time.now - 29 * 60, Time.now - 29 * 60, @stat_file)
          get '/get_status'
          @response = last_response
        end

        it "現在の温度を json で返すこと" do
          res = JSON.parse(@response.body)
          res.has_key?('temp').must_equal true
          res['temp'].to_f.must_equal @temp
        end
      end

      after do
        File.delete(@stat_file) if File.exists?(@stat_file)
      end
    end
  end
end
