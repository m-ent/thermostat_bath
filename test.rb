require 'minitest/autorun'
require './main'

class Mock_temp
  attr_reader :temp_list

  def initialize(temp_list = nil)
    @state = -1
    if temp_list
      @temp_list = temp_list
    else
      @temp_list = [30.0, 31.0, 32.0, 33.0, 34.0, 35.0, 36.0]
    end
  end

  def call
    if @state < @temp_list.length
      @state += 1
    end
    @temp_list[@state]
  end
end

describe Thermo_controller do
  describe '#get_temp' do
    subject { Thermo_controller.new }
    it 'stubのテスト: ダミーデータが得られること' do
      # ref: minitest で mock や stub を使う
      # http://blog.willnet.in/entry/2012/12/05/004010
      mock_temp = Mock_temp.new
      # stubの戻り値に 1) 値を指定できる
      #                2) #call をもつオブジェクトを指定できる
      subject.stub(:get_temp, mock_temp) do
        subject.get_temp.wont_equal nil
      end
    end

    it 'stubのテスト: 呼び出す度に異なったダミーデータが得られること' do
      mock_temp = Mock_temp.new {}
      subject.stub(:get_temp, mock_temp) do
        t0 = subject.get_temp
        subject.get_temp.wont_equal t0
      end
    end
  end

  describe '#calc_power' do
    describe '比例制御について' do
      subject { Thermo_controller.new(36.0, 10.0, 1.0, 0, 0) }
      it '温度差が倍の時、出力も倍になること' do
        p = subject.calc_power(0.0, 34.0)
        (subject.calc_power(34.0, 35.0) * 2).must_equal p
      end
    end

    describe '積分制御について' do
      subject { Thermo_controller.new(36.0, 10.0, 1.0, 0.1, 0) }
      it '温度変化がなくても継続すると出力が増加すること' do
        p = subject.calc_power(30.0, 30.0)
        (subject.calc_power(30.0, 30.0) > p).must_equal true
      end
    end

    describe '微分制御について' do
      subject { Thermo_controller.new(36.0, 10.0, 1.0, 0, 0.1) }
      it '温度が上昇傾向の時よりも、低下傾向の時の方が出力が増加すること' do
        p = subject.calc_power(30.0, 32.0)
        (subject.calc_power(34.0, 32.0) > p).must_equal true
      end
    end

    subject { Thermo_controller.new(36.0, 10.0, 1.0, 1, 0) }
    it '現在の温度が目標値以上の時、出力が0になること' do
      subject.calc_power(30.0, 33.0)
      subject.calc_power(33.0, 36.0).must_equal 0
    end
  end

  describe '#log' do
    before do
      @tmp, @interval, @kp, @ki, @kd = 36.0, 1.0, 1.0, 0.1, 0.01
      @controller = Thermo_controller.new(@tmp, @interval, @kp, @ki, @kd)
      @log_file = 'temp.log'
      File.delete(@log_file) if File.exists?(@log_file)
      @mock_temp = Mock_temp.new {}
    end

    it 'log を on にすると log ファイルが作られ、sizeも0でないこと' do
      @controller.stub(:get_temp, @mock_temp) do
        @controller.log(:on)
        @controller.start(5)
        File.exists?(@log_file).must_equal true
        File::Stat.new(@log_file).size.wont_equal 0
      end
    end

    it 'log を on にすると log ファイルの最初に条件が記録されること' do
      @controller.stub(:get_temp, @mock_temp) do
        @controller.log(:on)
        @controller.start(5)
        condition = \
          "target: #{@tmp}, interval: #{@interval}, Kp: #{@kp}, Ki: #{@ki}, Kd: #{@kd}" 
p condition
        log = ""
        File.open(@log_file) do |f|
          log = f.gets.chomp
        end
        log.must_equal condition
      end

    end

    it 'log を on にすると log ファイルに温度が記録されること' do
      @controller.stub(:get_temp, @mock_temp) do
        @controller.log(:on)
        @controller.start(5)
        log = ""
        File.open(@log_file) do |f|
          while (l = f.gets) do
            log += "#{l.chomp} "
          end
        end
        t = @mock_temp.temp_list
        t_reg = ""
        (1..5).each do |i|
          t_reg += "#{t[i]}.*"
        end
        log.must_match Regexp.new(t_reg)
      end
    end

    it 'log を off にすると log ファイルが作られないこと' do
      @controller.stub(:get_temp, @mock_temp) do
        @controller.log(:off)
        @controller.start(5)
        File.exists?(@log_file).wont_equal true
      end
    end
  end

  describe '#on_fly' do
    describe 'on_fly モードではない場合' do
      before do
        @controller = Thermo_controller.new
        @controller.on_fly(:off)
      end

      it '#get_temp が 0.0 を返すこと' do
        @controller.get_temp.must_equal 0.0
      end
    end

    describe 'on_fly モードの場合' do
      before do
        @controller = Thermo_controller.new
        @controller.on_fly(:on)
      end

      it '#get_temp が例外を返すこと' do
        assert_raises NoMethodError do
          @controller.get_temp
        end
      end

      it '#power により gpio 関連のエラーが出ること' do
        out, err = capture_subprocess_io do
          @controller.power(:on, 1)
        end

        err.must_match /gpio/
      end
    end
  end
end

