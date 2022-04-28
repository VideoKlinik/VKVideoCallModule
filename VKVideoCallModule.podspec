Pod::Spec.new do |s|

s.name               = "VKVideoCallModule"

s.version            = "1.0.0"

s.summary         = "VKVideoCallModule"

s.license              = "MIT"

s.homepage = "http://www.dijitalgaraj.com/"

s.author               = "Dijital Garaj"

s.platform            = :ios

s.ios.deployment_target = '11.0'

s.source              = { :git => "https://github.com/VideoKlinik/VKVideoCallModule", :tag => "1.0.0" }

s.xcconfig = { "FRAMEWORK_SEARCH_PATHS" => "$(SRCROOT)/"}

s.static_framework = true

s.dependency 'TwilioVideo', '3.7.1'

s.source_files = "VKVideoCallModule/**/*.{swift}"

s.resources = "VKVideoCallModule/**/*.{storyboard,png}"

end
