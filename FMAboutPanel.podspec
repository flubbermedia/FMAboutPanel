Pod::Spec.new do |s|
  s.name             = 'FMAboutPanel'
  s.version          = '1.0.0'
  s.summary          = 'A class designed to show an *About Panel* with many useful features.'
  s.homepage         = 'https://github.com/flubbermedia/FMAboutPanel'
  s.license          = 'MIT'
  s.authors          = 'Andrea Ottolina', 'Maurizio Cremaschi'
  s.source           = { :git => 'https://github.com/flubbermedia/FMAboutPanel.git', :tag => s.version.to_s }

  s.platform     = :ios, '5.0'
  s.ios.deployment_target = '5.0'
  s.requires_arc = true

  s.source_files = 'FMAboutPanel/FMAboutPanel.{h,m}'
  s.resource = 'FMAboutPanel/FMAboutPanel.bundle'

  s.frameworks = 'UIKit', 'QuartzCore'
  s.dependency 'zipzap', '~>8.0'
  s.dependency 'ChimpKit2', '~>2.0'
end
