Pod::Spec.new do |s|
  s.name     = 'RxGRDB'
  s.version  = '0.13.0'
  
  s.license  = { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'Reactive extensions for GRDB.swift.'
  s.homepage = 'https://github.com/RxSwiftCommunity/RxGRDB'
  s.author   = { 'Gwendal Roué' => 'gr@pierlis.com' }
  s.source   = { :git => 'https://github.com/RxSwiftCommunity/RxGRDB.git', :tag => "v#{s.version}" }
  s.module_name = 'RxGRDB'
  
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'
  s.watchos.deployment_target = '2.0'
  
  s.dependency "RxSwift", "~> 5.0"
  s.default_subspec = 'default'
  
  s.subspec 'default' do |ss|
    ss.source_files = 'RxGRDB/**/*.{h,swift}'
    ss.dependency "GRDB.swift", "~> 3.5"
  end
  
  s.subspec 'GRDBCipher' do |ss|
    ss.source_files = 'RxGRDB/**/*.{h,swift}'
    ss.dependency "GRDBCipher", "~> 3.5"
    ss.xcconfig = {
      'OTHER_SWIFT_FLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DUSING_SQLCIPHER',
      'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DUSING_SQLCIPHER',
    }
  end
end
