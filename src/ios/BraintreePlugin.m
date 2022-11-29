//
//  BraintreePlugin.m
//
//  Copyright (c) 2022 Jean-Christophe Hoelt. All rights reserved.
//

#import "BraintreePlugin.h"
#import <objc/runtime.h>
#import <BraintreeDropIn/BraintreeDropIn.h>

/*
 * Constants
 */

#define VERBOSITY_DEBUG  0
#define VERBOSITY_INFO  10
#define VERBOSITY_WARN  20
#define VERBOSITY_ERROR 30

@interface BraintreePlugin()
@end

@implementation BraintreePlugin

/// Callback called to send native logs to javascript
NSString *loggerCallback = nil;

/// Level of verbosity for the plugin
long verbosityLevel = VERBOSITY_INFO;

/// Prefix used for logs from the braintree plugin
static const NSString *LOG_PREFIX = @"CordovaPlugin.Braintree";

#pragma mark - Cordova commands

/// Change the plugin verbosirty level
- (void) setVerbosity:(CDVInvokedUrlCommand*)command {
    NSNumber *value = [command argumentAtIndex:0
                                   withDefault:[NSNumber numberWithInt: VERBOSITY_INFO]
                                      andClass:[NSNumber class]];
    verbosityLevel = value.integerValue;
    [self debug:[NSString stringWithFormat:@"[setVerbosity] %zd", verbosityLevel]];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/// Set a callback that will display native logs in javascript
- (void) setLogger:(CDVInvokedUrlCommand*)command {
    loggerCallback = command.callbackId;
    [self debug:[NSString stringWithFormat:@"[setLogger] %@", loggerCallback]];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    pluginResult.keepCallback = [NSNumber  numberWithBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) launchDropInWithClientToken:(CDVInvokedUrlCommand *)command {
    NSString *clientToken = [command.arguments objectAtIndex:0];
    [self debug:[NSString stringWithFormat:@"[launchDropInWithClientToken] %@", clientToken]];

    BTDropInRequest *dropInRequest = [[BTDropInRequest alloc] init];
    BTDropInController *dropInController = [
        [BTDropInController alloc]
        initWithAuthorization:clientToken
        request:dropInRequest
        handler:^(BTDropInController * _Nonnull controller, BTDropInResult * _Nullable result, NSError * _Nullable error) {
            if (error != nil) {
                [self sendPluginError:error toCommand:command];
            }
            else if (result.isCanceled) {
                CDVPluginResult *pluginResult = [CDVPluginResult
                                                 resultWithStatus:CDVCommandStatus_ERROR
                                                 messageAsString:@"UserCanceledException|Modal was dismissed without selecting a payment method"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
            else {
                CDVPluginResult *pluginResult = [CDVPluginResult
                                                 resultWithStatus:CDVCommandStatus_OK
                                                 messageAsDictionary:[self dictionaryFromDropInResult:result]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
            [self.viewController dismissViewControllerAnimated:NO completion:^{
                // view controller dismissed.
            }];
        }
    ];

    [self.viewController presentViewController:dropInController animated:NO completion:^{
        // view controller presented.
    }];
}

#pragma mark - Helpers

/**
 * Helper used to return a dictionary of values from the given payment method nonce.
 * Handles several different types of nonces (eg for cards, Apple Pay, PayPal, etc).
 */
- (NSDictionary*)dictionaryFromPaymentMethodNonce:(BTPaymentMethodNonce *)paymentMethodNonce {
    
    NSDictionary *dictionary = @{
        // Standard Fields
        @"nonce": paymentMethodNonce.nonce,
        @"type": paymentMethodNonce.type,
        @"isDefault": @(paymentMethodNonce.isDefault)
    };
    
    return dictionary;
}

/** Values for payment methods */
const NSString *PT_AMEX = @"AMEX";
const NSString *PT_APPLE_PAY = @"APPLE_PAY";
const NSString *PT_GOOGLE_PAY = @"GOOGLE_PAY";
const NSString *PT_DINERS_CLUB = @"DINERS_CLUB";
const NSString *PT_DISCOVER = @"DISCOVER";
const NSString *PT_JCB = @"JCB";
const NSString *PT_MAESTRO = @"MAESTRO";
const NSString *PT_MASTERCARD = @"MASTERCARD";
const NSString *PT_PAYPAL = @"PAYPAL";
const NSString *PT_VISA = @"VISA";
const NSString *PT_VENMO = @"VENMO";
const NSString *PT_UNIONPAY = @"UNIONPAY";
const NSString *PT_HIPER = @"HIPER";
const NSString *PT_HIPERCARD = @"HIPERCARD";
const NSString *PT_LASER = @"LASER";
const NSString *PT_UK_MAESTRO = @"UK_MAESTRO";
const NSString *PT_SWITCH = @"SWITCH";
const NSString *PT_SOLO = @"SOLO";
const NSString *PT_UNKNOWN = @"UNKNOWN";

- (const NSString *)fromDropInPaymentMethodType:(BTDropInPaymentMethodType)type {
    switch (type) {
        case BTDropInPaymentMethodTypeUnknown: return PT_UNKNOWN;
        case BTDropInPaymentMethodTypeAMEX: return PT_AMEX;
        case BTDropInPaymentMethodTypeDinersClub: return PT_DINERS_CLUB;
        case BTDropInPaymentMethodTypeDiscover: return PT_DISCOVER;
        case BTDropInPaymentMethodTypeMasterCard: return PT_MASTERCARD;
        case BTDropInPaymentMethodTypeVisa: return PT_VISA;
        case BTDropInPaymentMethodTypeJCB: return PT_JCB;
        case BTDropInPaymentMethodTypeLaser: return PT_LASER;
        case BTDropInPaymentMethodTypeMaestro: return PT_MAESTRO;
        case BTDropInPaymentMethodTypeUnionPay: return PT_UNIONPAY;
        case BTDropInPaymentMethodTypeHiper: return PT_HIPER;
        case BTDropInPaymentMethodTypeHipercard: return PT_HIPERCARD;
        case BTDropInPaymentMethodTypeSolo: return PT_SOLO;
        case BTDropInPaymentMethodTypeSwitch: return PT_SWITCH;
        case BTDropInPaymentMethodTypeUKMaestro: return PT_UK_MAESTRO;
        case BTDropInPaymentMethodTypePayPal: return PT_PAYPAL;
        case BTDropInPaymentMethodTypeVenmo: return PT_VENMO;
        case BTDropInPaymentMethodTypeApplePay: return PT_APPLE_PAY;
    }
}

/// Converts a DropInResult to NSDictionary (to return to the plugin)
///
/// Should corresponds to CdvPurchase.Braintree.DropIn.Result in typescript
- (NSDictionary*)dictionaryFromDropInResult:(BTDropInResult*)result {
    return @{
        @"deviceData": result.deviceData,
        @"paymentDescription": result.paymentDescription,
        @"paymentMethodNonce": [self dictionaryFromPaymentMethodNonce:result.paymentMethod],
        @"paymentMethodType": [self fromDropInPaymentMethodType:result.paymentMethodType]
    };
}

/// Send an error back to the caller, log it to the console.
- (void) sendPluginError: (NSError*) error toCommand:(CDVInvokedUrlCommand *)command {
    [self error:[NSString stringWithFormat:@"Code: %zd", [error code]]];
    [self error:[NSString stringWithFormat:@"Description: %@", [error localizedDescription]]];
    NSString *errorString = [NSString stringWithFormat:@"%zd|%@", error.code, error.localizedDescription];
    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorString];
    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
}

/// Log a message to the console
- (void) log:(int)level message:(NSString*)message {
    if (level >= verbosityLevel) {
        NSLog(@"[%@] %@", LOG_PREFIX, message);
        if (loggerCallback != nil) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
            pluginResult.keepCallback = [NSNumber  numberWithBool:YES];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:loggerCallback];
        }
    }
}
- (void) debug:(NSString*)message { [self log:VERBOSITY_DEBUG message:message]; }
- (void) info:(NSString*)message { [self log:VERBOSITY_INFO message:message]; }
- (void) warn:(NSString*)message { [self log:VERBOSITY_WARN message:message]; }
- (void) error:(NSString*)message { [self log:VERBOSITY_ERROR message:message]; }

@end

