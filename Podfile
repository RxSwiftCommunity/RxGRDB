use_frameworks!
workspace 'RxGRDB.xcworkspace'

def common
    pod 'RxSwift', '~> 4.0'
    pod 'GRDB.swift', :git => 'https://github.com/groue/GRDB.swift.git', :branch => 'feature/ValueObservation' # '~> 3.3'
end

target 'RxGRDBiOS' do
  platform :ios, '8.0'
  common
end

target 'RxGRDBmacOS' do
  platform :macos, '10.10'
  common
end

target 'RxGRDBiOSTests' do
  platform :ios, '8.0'
  common
end

target 'RxGRDBmacOSTests' do
  platform :macos, '10.10'
  common
end

target 'RxGRDBDemo' do
  project 'Documentation/RxGRDBDemo/RxGRDBDemo.xcodeproj'
  platform :ios, '8.0'
  pod 'Differ', '~> 1.0'
  pod 'RxGRDB', :path => '.'
end
