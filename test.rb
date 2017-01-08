require 'minitest/autorun'
require './main'

describe Thermo_controller do

  describe '#get_temp' do
    subject { Thermo_controller.new }

    it 'stubのテスト: ダミーデータ 34.0が得られるかどうか' do
      # ref: minitest で mock や stub を使う
      # http://blog.willnet.in/entry/2012/12/05/004010
      subject.stub(:get_temp, 34.0) do
        subject.get_temp.must_equal 34.0
      end
    end

    it 'stubのテスト: ダミーデータ 30.0が得られるかどうか' do
      subject.stub(:get_temp, 30.0) do
        subject.get_temp.wont_equal 34.0
      end
    end
  end

end

#t = Thermo_controller.new(36.0, 3.0, 2.0, 0.0, 0.0)
  #e.g.: Kp: 1.0-3.0, Ki: 0.005, Kd: 
#t.start

