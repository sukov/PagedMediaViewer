Pod::Spec.new do |s|
  s.name             = 'PagedMediaViewer'
  s.version          = '1.0.2'
  s.summary          = 'Elegant media display library, comparable to native Photos app, supporting both images and videos.'

  s.homepage         = 'https://github.com/sukov/PagedMediaViewer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'sukov' => 'gorjan5@hotmail.com' }
  s.source           = { :git => 'https://github.com/sukov/PagedMediaViewer.git', :tag => s.version.to_s }
  s.documentation_url = 'https://sukov.github.io/PagedMediaViewer/'

  s.swift_version = '5.5'
  s.ios.deployment_target = '13.0'

  s.source_files = 'Source/Classes/**/*'
  s.frameworks = 'UIKit'
end
