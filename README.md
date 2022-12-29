# AppExaminer

[Facebook Flipper](https://github.com/facebook/flipper) iOS client side reimplementation with simpler dependencies.

- Supports Swift Package Manager.


Missing feature(s):
- Device connection work only if you inject you Mac device (which is running 
Flipper macOS app) host ip address using environment variable 
`FLIPPER_HOST_ADDRESS` and have that device tethered though USB.
- No default plugins.



TODO:
- Integrate SwiftLint and SwiftFormatter
- Add default plugins
- Add Carthage support
- Add CocoaPods support
- Switch SocketRocket dependency to `facebookincubator/SocketRocket` once SPM support has been added. https://github.com/facebookincubator/SocketRocket/pull/631
