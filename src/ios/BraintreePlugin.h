//
//  BraintreePlugin.h
//

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>

@interface BraintreePlugin : CDVPlugin
- (void) launchDropIn:(CDVInvokedUrlCommand *)command;
- (void) setLogger:(CDVInvokedUrlCommand *)command;
- (void) setVerbosity:(CDVInvokedUrlCommand*)command;

// Return a boolean, true if ApplePay is supported.
- (void) isApplePaySupported:(CDVInvokedUrlCommand*)command;
@end
