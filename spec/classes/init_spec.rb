require 'spec_helper'

describe 'icsurvey' do

  context 'with defaults for all parameters' do
    it { should contain_class('cicserver::icsurvey') }
  end
end
