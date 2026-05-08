Pod::Spec.new do |s|
  s.name             = 'synheart_session'
  s.version          = '0.2.0'
  s.summary          = 'iOS implementation of Synheart Session plugin.'
  s.homepage         = 'https://github.com/synheart-ai/synheart-session-flutter'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = { 'Synheart AI' => 'dev@synheart.ai' }
  s.source           = { :http => 'https://github.com/synheart-ai/synheart-session-flutter' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.9'
  s.frameworks       = 'WatchConnectivity'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }
end
