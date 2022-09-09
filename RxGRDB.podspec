Pod::Spec.new do |s|
  s.name     = 'RxGRDB'
  s.version  = '3.0.0'
  
  s.license  = { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'Reactive extensions for GRDB.swift.'
  s.homepage = 'https://github.com/RxSwiftCommunity/RxGRDB'
  s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
  s.source   = { :git => 'https://github.com/RxSwiftCommunity/RxGRDB.git', :tag => "v#{s.version}" }
  s.module_name = 'RxGRDB'
  
  s.swift_versions = ['5.7']
  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.13'
  s.watchos.deployment_target = '4.0'
  s.tvos.deployment_target = '11.0'
  
  s.dependency "RxSwift", "~> 6.0"
  s.default_subspec = 'default'
  
  s.subspec 'default' do |ss|
    ss.source_files = 'Sources/RxGRDB/**/*.{swift}'
    ss.dependency "GRDB.swift", "~> 6.0"
  end
  
  s.subspec 'SQLCipher' do |ss|
    ss.source_files = 'Sources/RxGRDB/**/*.{swift}'
    ss.dependency "GRDB.swift/SQLCipher", "~> 6.0"
    ss.xcconfig = {
      'OTHER_SWIFT_FLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DUSING_SQLCIPHER',
      'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DUSING_SQLCIPHER',
    }
  end
end
