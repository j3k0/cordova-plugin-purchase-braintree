# Contributing to cordova-plugin-purchase-braintree

## Installation workarounds

### Braintree iOS SDK

The Braintree SDK could be installed with CocoaPods, however one of the frameworks crashes at initialization. The error is pretty uninformative, I couldn't figure out what happens.
However, when installing the frameworks manually from the "xcframework" release [available on github](https://github.com/braintree/braintree_ios/releases), it works.

Instead of including 44MB into the project, the plugin contains a hook in `scripts/iosBeforeInstall.js` that downloads and extracts the required `xcframework` files from github.

### Braintree iOS Drop In SDK

For iOS, the recommended procedure for installing the Braintree Drop In SDK is to use either:

- the Swift Package Manager, which [isn't yet supported by Cordova](https://github.com/apache/cordova-ios/issues/1089).
- CocoaPods, which [has some issues](https://github.com/CocoaPods/CocoaPods/issues/10675) when used with custom build directories (which is the case with Cordova).
  - Unfortunately this issue occurs when installing Braintree Drop In SDK.

To solve this, I resorted in including the source code for Braintree Drop In (license is MIT). All source files are listed in the `plugin.xml` file. The list is long, so there's a helper script to generate this section of XML: `gen-ios-source-files.sh`. It also adds a custom compilation argument to those files so the "imports" work.

To **update the Braintree Drop In SDK**:

1. Copy in `src/ios/BraintreeDropIn`, from the [braintree-ios-drop-in github repository](https://github.com/braintree/braintree-ios-drop-in/).
2. Move the resource bundle containing localization strings, from `src/ios/BraintreeDropIn/Resources` into `src/ios/BraintreeDropIn-Resources.bundle/`.

If the list of source files has changed: use the `gen-ios-source-files.sh` files to update the list of source files in `plugin.xml`.

##  Pull Requests

They're welcome!