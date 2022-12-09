//
//  BraintreePlugin.m
//
//  Copyright (c) 2022 Jean-Christophe Hoelt. All rights reserved.
//

#import "BraintreePlugin.h"
#import <objc/runtime.h>
#import <BraintreeDropIn/BraintreeDropIn.h>
#import <BraintreeApplePay/BraintreeApplePay.h>
#import <BraintreeThreeDSecure/BTThreeDSecurePostalAddress.h>
#import <BraintreeThreeDSecure/BTThreeDSecureAdditionalInformation.h>

/*
 * Constants
 */

#define VERBOSITY_DEBUG 4
#define VERBOSITY_INFO 3
#define VERBOSITY_WARN 2
#define VERBOSITY_ERROR 1

@implementation BraintreePlugin

/// Callback called to send native logs to javascript
static NSString *loggerCallback = nil;

static BTAPIClient *apiClient = nil;

/// Level of verbosity for the plugin
static long verbosityLevel = VERBOSITY_INFO;

/// Prefix used for logs from the braintree plugin
static const NSString *LOG_PREFIX = @"CordovaPurchase.Braintree.objc";

#pragma mark - Cordova commands

/// Change the plugin verbosirty level
- (void) setVerbosity:(CDVInvokedUrlCommand*)command {
    NSNumber *value = [command argumentAtIndex:0
                                   withDefault:[NSNumber numberWithInt: VERBOSITY_INFO]
                                      andClass:[NSNumber class]];
    verbosityLevel = [value intValue];
    [self info:[NSString stringWithFormat:@"[setVerbosity] %zd", verbosityLevel]];
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

#pragma mark - Parsing

+ (BOOL)boolIn:(NSDictionary*)options forKey:(NSString*)key withDefault:(BOOL)defaultValue {
    id value = [options valueForKey:key];
    if (value == nil) return defaultValue;
    return [(NSNumber*)value boolValue];
}

+ (NSString*)stringIn:(NSDictionary*)options forKey:(NSString*)key {
    id value = [options valueForKey:key];
    if (value == nil) return nil;
    return (NSString*)value;
}

/// Decimal number passed as a string
+ (NSDecimalNumber*)decimalNumberIn:(NSDictionary*)options forKey:(NSString*)key {
    NSString *value = [BraintreePlugin stringIn:options forKey:key];
    if (value == nil) return nil;
    return [NSDecimalNumber decimalNumberWithString:value];
}

+ (NSDate*)dateIn:(NSDictionary*)options forKey:(NSString*)key {
    NSNumber *value = [options valueForKey:key];
    if (value == nil) return nil;
    return [NSDate dateWithTimeIntervalSince1970:[value doubleValue]/1000];
}

/// This returns an NSCalendarUnit from an IPeriodUnit.
/// Note: the value "Week" is not supported.
+ (NSCalendarUnit)calendarUnitIn:(NSDictionary*)options forKey:(NSString*)key withDefault:(NSCalendarUnit)defaultValue {
    NSString *value = [options valueForKey:key];
    if (value == nil) return defaultValue;
    if ([value isEqualToString:@"Minute"]) return NSCalendarUnitMinute;
    if ([value isEqualToString:@"Hour"]) return NSCalendarUnitHour;
    if ([value isEqualToString:@"Day"]) return NSCalendarUnitDay;
    if ([value isEqualToString:@"Month"]) return NSCalendarUnitMonth;
    if ([value isEqualToString:@"Year"]) return NSCalendarUnitYear;
    return defaultValue;
}

- (BTThreeDSecureAccountType) parseThreeDSecureAccountType: (NSString*)value {
    if (value == nil) return BTThreeDSecureAccountTypeUnspecified;
    if ([value isEqualToString:@"00"]) return BTThreeDSecureAccountTypeUnspecified;
    if ([value isEqualToString:@"01"]) return BTThreeDSecureAccountTypeCredit;
    if ([value isEqualToString:@"02"]) return BTThreeDSecureAccountTypeDebit;
    return BTThreeDSecureAccountTypeUnspecified;
}

- (BTThreeDSecurePostalAddress*) parseThreeDSecurePostalAddress: (NSDictionary*)address {
    if (address == nil) return nil;
    BTThreeDSecurePostalAddress *ret = [[BTThreeDSecurePostalAddress alloc] init];
    ret.givenName = [BraintreePlugin stringIn:address forKey:@"givenName"];
    ret.surname = [BraintreePlugin stringIn:address forKey:@"surname"];
    ret.streetAddress = [BraintreePlugin stringIn:address forKey:@"streetAddress"];
    ret.extendedAddress = [BraintreePlugin stringIn:address forKey:@"extendedAddress"];
    ret.line3 = [BraintreePlugin stringIn:address forKey:@"line3"];
    ret.locality = [BraintreePlugin stringIn:address forKey:@"locality"];
    ret.region = [BraintreePlugin stringIn:address forKey:@"region"];
    ret.postalCode = [BraintreePlugin stringIn:address forKey:@"postalCode"];
    ret.phoneNumber = [BraintreePlugin stringIn:address forKey:@"phoneNumber"];
    ret.countryCodeAlpha2 = [BraintreePlugin stringIn:address forKey:@"countryCodeAlpha2"];
    return ret;
}

- (BTThreeDSecureShippingMethod) parseThreeDSecureShippingMethod:(NSNumber*)value {
    if (value == nil) return BTThreeDSecureShippingMethodUnspecified;
    if ([value isEqualToNumber:@0]) return BTThreeDSecureShippingMethodUnspecified;
    if ([value isEqualToNumber:@1]) return BTThreeDSecureShippingMethodSameDay;
    if ([value isEqualToNumber:@2]) return BTThreeDSecureShippingMethodExpedited;
    if ([value isEqualToNumber:@3]) return BTThreeDSecureShippingMethodPriority;
    if ([value isEqualToNumber:@4]) return BTThreeDSecureShippingMethodGround;
    if ([value isEqualToNumber:@5]) return BTThreeDSecureShippingMethodElectronicDelivery;
    if ([value isEqualToNumber:@6]) return BTThreeDSecureShippingMethodShipToStore;
    return BTThreeDSecureShippingMethodUnspecified;
}

- (BTThreeDSecureVersion) parseThreeDSecureVersion: (NSNumber*)value {
    if (value == nil) return BTThreeDSecureVersion2;
    if ([value isEqualToNumber:@0]) return BTThreeDSecureVersion1;
    return BTThreeDSecureVersion2;
}

- (BTThreeDSecureCardAddChallenge) parseThreeDSecureCardAddChallenge: (NSNumber*)value {
    if (value == nil) return BTThreeDSecureCardAddChallengeUnspecified;
    if ([value boolValue] == YES) return BTThreeDSecureCardAddChallengeRequested;
    if ([value boolValue] == NO) return BTThreeDSecureCardAddChallengeNotRequested;
    return BTThreeDSecureCardAddChallengeUnspecified;
}

- (BTThreeDSecureAdditionalInformation*) parseThreeDSecureAdditionalInformation: (NSDictionary*)data {
    if (data == nil) return nil;
    BTThreeDSecureAdditionalInformation *ret = [[BTThreeDSecureAdditionalInformation alloc] init];
    ret.shippingAddress = [self parseThreeDSecurePostalAddress:[data valueForKey:@"shippingAddress"]];
    ret.shippingMethodIndicator = [BraintreePlugin stringIn:data forKey:@"shippingMethodIndicator"];
    ret.productCode = [BraintreePlugin stringIn:data forKey:@"productCode"];
    ret.deliveryTimeframe = [BraintreePlugin stringIn:data forKey:@"deliveryTimeframe"];
    ret.deliveryEmail = [BraintreePlugin stringIn:data forKey:@"deliveryEmail"];
    ret.reorderIndicator = [BraintreePlugin stringIn:data forKey:@"reorderIndicator"];
    ret.preorderIndicator = [BraintreePlugin stringIn:data forKey:@"preorderIndicator"];
    ret.preorderDate = [BraintreePlugin stringIn:data forKey:@"preorderDate"];
    ret.giftCardAmount = [BraintreePlugin stringIn:data forKey:@"giftCardAmount"];
    ret.giftCardCurrencyCode = [BraintreePlugin stringIn:data forKey:@"giftCardCurrencyCode"];
    ret.giftCardCount = [BraintreePlugin stringIn:data forKey:@"giftCardCount"];
    ret.accountAgeIndicator = [BraintreePlugin stringIn:data forKey:@"accountAgeIndicator"];
    ret.accountCreateDate = [BraintreePlugin stringIn:data forKey:@"accountCreateDate"];
    ret.accountChangeIndicator = [BraintreePlugin stringIn:data forKey:@"accountChangeIndicator"];
    ret.accountChangeDate = [BraintreePlugin stringIn:data forKey:@"accountChangeDate"];
    ret.accountPwdChangeIndicator = [BraintreePlugin stringIn:data forKey:@"accountPwdChangeIndicator"];
    ret.accountPwdChangeDate = [BraintreePlugin stringIn:data forKey:@"accountPwdChangeDate"];
    ret.shippingAddressUsageIndicator = [BraintreePlugin stringIn:data forKey:@"shippingAddressUsageIndicator"];
    ret.shippingAddressUsageDate = [BraintreePlugin stringIn:data forKey:@"shippingAddressUsageDate"];
    ret.transactionCountDay = [BraintreePlugin stringIn:data forKey:@"transactionCountDay"];
    ret.transactionCountYear = [BraintreePlugin stringIn:data forKey:@"transactionCountYear"];
    ret.addCardAttempts = [BraintreePlugin stringIn:data forKey:@"addCardAttempts"];
    ret.accountPurchases = [BraintreePlugin stringIn:data forKey:@"accountPurchases"];
    ret.fraudActivity = [BraintreePlugin stringIn:data forKey:@"fraudActivity"];
    ret.shippingNameIndicator = [BraintreePlugin stringIn:data forKey:@"shippingNameIndicator"];
    ret.paymentAccountIndicator = [BraintreePlugin stringIn:data forKey:@"paymentAccountIndicator"];
    ret.paymentAccountAge = [BraintreePlugin stringIn:data forKey:@"paymentAccountAge"];
    ret.addressMatch = [BraintreePlugin stringIn:data forKey:@"addressMatch"];
    ret.accountID = [BraintreePlugin stringIn:data forKey:@"accountID"];
    ret.ipAddress = [BraintreePlugin stringIn:data forKey:@"ipAddress"];
    ret.orderDescription = [BraintreePlugin stringIn:data forKey:@"orderDescription"];
    ret.taxAmount = [BraintreePlugin stringIn:data forKey:@"taxAmount"];
    ret.userAgent = [BraintreePlugin stringIn:data forKey:@"userAgent"];
    ret.authenticationIndicator = [BraintreePlugin stringIn:data forKey:@"authenticationIndicator"];
    ret.installment = [BraintreePlugin stringIn:data forKey:@"installment"];
    ret.purchaseDate = [BraintreePlugin stringIn:data forKey:@"purchaseDate"];
    ret.recurringEnd = [BraintreePlugin stringIn:data forKey:@"recurringEnd"];
    ret.recurringFrequency = [BraintreePlugin stringIn:data forKey:@"recurringFrequency"];
    ret.sdkMaxTimeout = [BraintreePlugin stringIn:data forKey:@"sdkMaxTimeout"];
    ret.workPhoneNumber = [BraintreePlugin stringIn:data forKey:@"workPhoneNumber"];
    return ret;
}

- (BTThreeDSecureRequest*) parseThreeDSecureRequest: (NSDictionary*)request {
    if (request == nil) return nil;
    BTThreeDSecureRequest *ret = [[BTThreeDSecureRequest alloc] init];
    ret.amount = [BraintreePlugin decimalNumberIn:request forKey:@"amount"];
    ret.nonce = [BraintreePlugin stringIn:request forKey:@"nonce"];
    ret.email = [BraintreePlugin stringIn:request forKey:@"email"];
    ret.billingAddress = [self parseThreeDSecurePostalAddress:[request valueForKey:@"billingAddress"]];
    ret.mobilePhoneNumber = [BraintreePlugin stringIn:request forKey:@"mobilePhoneNumber"];
    ret.shippingMethod = [self parseThreeDSecureShippingMethod:[request valueForKey:@"shippingMethod"]];
    ret.accountType = [self parseThreeDSecureAccountType:[BraintreePlugin stringIn:request forKey:@"accountType"]];
    ret.additionalInformation = [self parseThreeDSecureAdditionalInformation:[request valueForKey:@"additionalInformation"]];
    ret.versionRequested = [self parseThreeDSecureVersion:[request valueForKey:@"versionRequested"]];
    ret.challengeRequested = [BraintreePlugin boolIn:request forKey:@"challengeRequested" withDefault:NO];
    ret.exemptionRequested = [BraintreePlugin boolIn:request forKey:@"exemptionRequested" withDefault:NO];
    ret.cardAddChallenge = [self parseThreeDSecureCardAddChallenge:[request valueForKey:@"cardAddChallenge"]];
    return ret;
}

- (BTFormFieldSetting) parseFormFieldSetting: (NSNumber*)setting {
    if (setting == nil) return BTFormFieldDisabled;
    if ([setting isEqualToNumber:@1]) return BTFormFieldOptional;
    if ([setting isEqualToNumber:@2]) return BTFormFieldRequired;
    return BTFormFieldDisabled;
}

- (BTDropInRequest*) parseDropInRequest:(NSDictionary*)request {
    BTDropInRequest *ret = [[BTDropInRequest alloc] init];
    if (request == nil) return ret;
    
    ret.allowVaultCardOverride = [BraintreePlugin boolIn:request forKey:@"allowVaultCardOverride" withDefault:NO];
    ret.vaultCard = [BraintreePlugin boolIn:request forKey:@"vaultCard" withDefault:YES];
    ret.vaultManager = [BraintreePlugin boolIn:request forKey:@"vaultManager" withDefault:NO];
    
    ret.applePayDisabled = [BraintreePlugin boolIn:request forKey:@"applePayDisabled" withDefault:NO];
    ret.cardDisabled = [BraintreePlugin boolIn:request forKey:@"cardDisabled" withDefault:NO];
    ret.cardholderNameSetting = [self parseFormFieldSetting:(NSNumber*)([request valueForKey:@"cardholderNameStatus"])];
    ret.shouldMaskSecurityCode = [BraintreePlugin boolIn:request forKey:@"maskSecurityCode" withDefault:NO];
    ret.threeDSecureRequest = [self parseThreeDSecureRequest:(NSDictionary *)([request valueForKey:@"threeDSecureRequest"])];
    
    // TODO
    //    ret.payPalRequest;
    ret.paypalDisabled = [BraintreePlugin boolIn:request forKey:@"paypalDisabled" withDefault:NO];
    
    // TODO
    ret.venmoDisabled = [BraintreePlugin boolIn:request forKey:@"venmoDisabled" withDefault:NO];
    //    ret.venmoRequest;
    
    return ret;
}

#pragma mark - Drop In

- (void) launchDropIn:(CDVInvokedUrlCommand *)command {
    NSString *clientToken = [command argumentAtIndex:0];
    NSDictionary *request = [command argumentAtIndex:1];
    [self debug:[NSString stringWithFormat:@"[launchDropIn] clientToken:%@", clientToken]];

    BTDropInRequest *dropInRequest = [self parseDropInRequest: request];
    [self debug:[NSString stringWithFormat:@"> request:%@", dropInRequest]];
    [self debug:[NSString stringWithFormat:@"> request 3DS amount:%@", dropInRequest.threeDSecureRequest.amount]];

    BTDropInController *dropInController = [
        [BTDropInController alloc]
        initWithAuthorization:clientToken
        request:dropInRequest
        handler:^(BTDropInController * _Nonnull controller, BTDropInResult * _Nullable result, NSError * _Nullable error) {
            apiClient = controller.apiClient;
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

    if (paymentMethodNonce == nil) return nil;
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
    return PT_UNKNOWN;
}

/// Converts a DropInResult to NSDictionary (to return to the plugin)
///
/// Should corresponds to CdvPurchase.Braintree.DropIn.Result in typescript
- (NSDictionary*)dictionaryFromDropInResult:(BTDropInResult*)result {
    if (result == nil) return nil;
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
    if (level <= verbosityLevel) {
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

+ (BTAPIClient*) getClient {
    return apiClient;
}

@end
