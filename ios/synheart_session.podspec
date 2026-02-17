Pod::Spec.new do |s|
  s.name             = 'synheart_session'
  s.version          = '0.1.0'
  s.summary          = 'iOS implementation of Synheart Session plugin.'
  s.homepage         = 'https://github.com/synheart-ai/synheart-session-dart'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = { 'Synheart AI' => 'dev@synheart.ai' }
  s.source           = { :http => 'https://github.com/synheart-ai/synheart-session-dart' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.9'
  s.frameworks       = 'WatchConnectivity'

  # Synheart Flux (Rust) XCFramework for HSI-compliant physiological metrics
  s.vendored_frameworks = 'Frameworks/SynheartFlux.xcframework'
  s.preserve_paths = 'Frameworks/SynheartFlux.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => [
      '-L$(PODS_TARGET_SRCROOT)/Frameworks/SynheartFlux.xcframework/ios-arm64_x86_64-simulator',
      '-force_load $(PODS_TARGET_SRCROOT)/Frameworks/SynheartFlux.xcframework/ios-arm64_x86_64-simulator/libsynheart_flux.a'
    ].join(' '),
    'OTHER_LDFLAGS[sdk=iphoneos*]' => [
      '-L$(PODS_TARGET_SRCROOT)/Frameworks/SynheartFlux.xcframework/ios-arm64',
      '-force_load $(PODS_TARGET_SRCROOT)/Frameworks/SynheartFlux.xcframework/ios-arm64/libsynheart_flux.a'
    ].join(' ')
  }
end
