require 'rspec'
require 'stringio'
require 'timecop'
require 'tmpdir'
require 'tempfile'
require 'fakefs/safe'

require_relative '../lib/thrust'

RSpec.configure do |c|
  c.before(:all) { ENV['ANDROID_HOME'] = '/fake/android_home' }
  c.before(:each) { FakeFS.activate! }
  c.after(:each) { FakeFS.deactivate! }
end
