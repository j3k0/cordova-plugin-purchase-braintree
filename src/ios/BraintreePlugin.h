//
//  BraintreePlugin.h
//
//  Copyright (c) 2016 Justin Unterreiner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>

@interface BraintreePlugin : CDVPlugin
- (void)launchDropInWithClientToken:(CDVInvokedUrlCommand *)command;
- (void)setLogger:(CDVInvokedUrlCommand *)command;
- (void) setVerbosity:(CDVInvokedUrlCommand*)command;
@end
