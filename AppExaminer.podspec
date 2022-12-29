Pod::Spec.new do |s|
    s.name             = 'AppExaminer'
    s.version          = '0.1.0'
    s.summary          = '.'
    s.homepage         = '.'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Alvar Hansen' => 'alvar@hansen.ee' }
    s.source           = { :git => 'https://github.com/alvarhansen/AppExaminer.git', :tag => s.version.to_s }
    s.ios.deployment_target = '12.0'
    s.swift_version = '5.0'
    s.source_files = 'Sources/AppExaminer/**/*'

    s.dependency 'CertificateSigningRequest', '~> 1.27.0'
    s.dependency 'SocketRocket', '0.6.0'
end