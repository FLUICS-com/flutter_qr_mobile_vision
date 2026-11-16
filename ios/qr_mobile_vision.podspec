Pod::Spec.new do |s|
  s.name             = 'qr_mobile_vision'
  s.version          = '0.0.2'
  s.summary          = 'Plugin for reading QR codes and barcodes.'
  s.description      = <<-DESC
Plugin for reading QR codes and barcodes using Apple Vision.
                       DESC
  s.homepage         = 'https://github.com/rmtmckenzie/flutter_qr_mobile_vision'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Morgan McKenzie' => 'rmtmckenzie@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'qr_mobile_vision/Sources/qr_mobile_vision/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.5'
  s.swift_version = '5.0'

  s.static_framework = true
end
