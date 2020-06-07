Pod::Spec.new do |s|
  s.name     = 'RxGRDB'
  s.version  = '1.0.0-beta.2'
  
  s.license  = { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'Reactive extensions for GRDB.swift.'
  s.homepage = 'https://github.com/RxSwiftCommunity/RxGRDB'
  s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
  s.source   = { :git => 'https://github.com/RxSwiftCommunity/RxGRDB.git', :tag => "v#{s.version}" }
  s.module_name = 'RxGRDB'
  
  s.swift_versions = ['5.2']
  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '3.0'
  
  s.dependency "RxSwift", "~> 5.0"
  s.default_subspec = 'default'
  
  s.subspec 'default' do |ss|
    ss.source_files = 'Sources/RxGRDB/**/*.{swift}'
    ss.dependency "GRDB.swift", "~> 5.0-beta"
  end
  
  s.subspec 'SQLCipher' do |ss|
    ss.source_files = 'Sources/RxGRDB/**/*.{swift}'
    ss.dependency "GRDB.swift/SQLCipher", "~> 5.0-beta"
    ss.xcconfig = {
      'OTHER_SWIFT_FLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DUSING_SQLCIPHER',
      'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DUSING_SQLCIPHER',
    }
  end
end
