//
//  BraintreePlugin.m
//
//  Copyright (c) 2016 Justin Unterreiner. All rights reserved.
//

#import "BraintreePlugin.h"
#import <objc/runtime.h>
#import <BraintreeDropIn.h>

/*
 * Constants
 */

#define VERBOSITY_DEBUG  0
#define VERBOSITY_INFO  10
#define VERBOSITY_WARN  20
#define VERBOSITY_ERROR 30

//#import <Braintree/BTAPIClient.h>
//#import <Braintree/BTPaymentMethodNonce.h>
//#import <Braintree/BTCardNonce.h>
//#import <Braintree/BraintreeApplePay.h>
//#import <Braintree/BraintreeDataCollector.h>
//#import <Braintree/BraintreeThreeDSecure.h>

@interface BraintreePlugin() /*<PKPaymentAuthorizationViewControllerDelegate, BTViewControllerPresentingDelegate, BTThreeDSecureRequestDelegate>*/

//@property (nonatomic, strong) BTAPIClient * braintreeClient;
//@property (nonatomic, strong) BTDataCollector * dataCollector;
//@property (nonatomic, strong) NSString * _Nonnull deviceDataCollector;
//@property (nonatomic, strong) BTPaymentFlowDriver * paymentFlowDriver;
//@property NSString * token;

@end

@implementation BraintreePlugin

//NSString * dropInUIcallbackId;
//bool applePaySuccess;
//NSString * applePayMerchantID;
//NSString * currencyCode;
//NSString * countryCode;
//NSArray<PKPaymentNetwork> * supportedNetworks;
//NSString * threeDResultNonce;

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

/*
- (void)initialize:(CDVInvokedUrlCommand *)command {
    
    // Ensure we have the correct number of arguments.
    if ([command.arguments count] != 1) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"A token is required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }
    
    // Obtain the arguments.
    self.token = [command.arguments objectAtIndex:0];
    
    if (!self.token) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"A token is required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }
    
    self.braintreeClient = [[BTAPIClient alloc] initWithAuthorization:self.token];
    
    if (!self.braintreeClient) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The Braintree client failed to initialize."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }
    
    self.dataCollector = [[BTDataCollector alloc] initWithAPIClient:self.braintreeClient];
    [self.dataCollector collectDeviceData:^(NSString * _Nonnull deviceDataCollector) {
        // Save deviceData
        self.deviceDataCollector = deviceDataCollector;
    }];
    
    self.paymentFlowDriver = [[BTPaymentFlowDriver alloc] initWithAPIClient:self.braintreeClient];
    [self.paymentFlowDriver setViewControllerPresentingDelegate:self];
    
    //    NSString *bundle_id = [NSBundle mainBundle].bundleIdentifier;
    //    bundle_id = [bundle_id stringByAppendingString:@".payments"];
    //
    //    [BTAppContextSwitcher setReturnURLScheme:bundle_id];
    
    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
}

//
// PassKit
// -------
//
// Returns whether the user can make payments.
//
// returns the value from PassKit (Apple Pay and Wallet): PKPaymentAuthorizationViewController.canMakePayments
//
- (void)pkCanMakePayments:(CDVInvokedUrlCommand *)command {
    
    CDVPluginResult * pluginResult = [CDVPluginResult
                                      resultWithStatus:CDVCommandStatus_OK
                                      messageAsBool:PKPaymentAuthorizationViewController.canMakePayments];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

//
// PassKit
// -------
//
// Initialize PassKit (Apple Pay / Wallet)
//
- (void)pkSetOptions:(CDVInvokedUrlCommand *)command {
    
    // Ensure the client has been initialized.
    if (!self.braintreeClient) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The Braintree client must first be initialized via BraintreePlugin.initialize(token)"];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }
    
    if ([command.arguments count] != 4) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Merchant id, Currency code, Country code, and Supported Card Types are required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }
    
    if (PKPaymentAuthorizationViewController.canMakePayments) {
        applePayMerchantID = [command.arguments objectAtIndex:0];
        currencyCode = [command.arguments objectAtIndex:1];
        countryCode = [command.arguments objectAtIndex:2];
        NSSet * cardTypes = [command.arguments objectAtIndex:3];
        supportedNetworks = [self mapCardTypes:cardTypes];
        
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
    } else {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"ApplePay cannot be used."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
    }
}

//
// PassKit
// -------
//
// Present the payment UI.
//
- (void)pkPresentDropInPaymentUI:(CDVInvokedUrlCommand *)command {
    
    // Ensure the client has been initialized.
    if (!self.braintreeClient) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The Braintree client must first be initialized via BraintreePlugin.initialize(token)"];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }
    
    // Ensure we have the correct number of arguments.
    if ([command.arguments count] < 1) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"amount required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }
    
    // Obtain the arguments.
    NSString * amount = (NSString *)[command.arguments objectAtIndex:0];
    if ([amount isKindOfClass:[NSNumber class]]) {
        amount = [(NSNumber *)amount stringValue];
    }
    if (!amount) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"amount is required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }
    
    NSString * primaryDescription = [command.arguments objectAtIndex:1];
    
    NSSet * fields = [command.arguments objectAtIndex:2];
    NSSet<PKContactField> * shippingContactFields = [self mapContactFields:fields];
    
    // Save off the Cordova callback ID so it can be used in the completion handlers.
    dropInUIcallbackId = command.callbackId;
    
    [self presentApplePayWithDescription:primaryDescription amount:amount andRequiredShippingContactFields:shippingContactFields];
}

- (void)startPaymentFlow:(CDVInvokedUrlCommand *)command {
    BTThreeDSecureRequest * threeDSecureRequest = [[BTThreeDSecureRequest alloc] init];
    
    [threeDSecureRequest setAmount: [NSDecimalNumber decimalNumberWithString: (NSString *)[command.arguments objectAtIndex:0]]];
    [threeDSecureRequest setNonce: (NSString *)[command.arguments objectAtIndex:1]];
    [threeDSecureRequest setEmail: (NSString *)[command.arguments objectAtIndex:2]];
    
    BTThreeDSecurePostalAddress * address = [[BTThreeDSecurePostalAddress alloc] init];
    [address setGivenName: (NSString *)[command.arguments objectAtIndex:3]];
    [address setSurname: (NSString *)[command.arguments objectAtIndex:4]];
    [address setPhoneNumber: (NSString *)[command.arguments objectAtIndex:5]];
    [address setCountryCodeAlpha2: (NSString *)[command.arguments objectAtIndex:6]];
    [threeDSecureRequest setBillingAddress:address];
    
    [threeDSecureRequest setVersionRequested:BTThreeDSecureVersion2];
    [threeDSecureRequest setThreeDSecureRequestDelegate:self];
    
    // Reset cached nonce
    threeDResultNonce = nil;
    
    [self.paymentFlowDriver startPaymentFlow:threeDSecureRequest completion:^(BTPaymentFlowResult * _Nullable result, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error Code: %zd", [error code]);
            NSLog(@"Error Desc: %@", [error localizedDescription]);
            
            // Match the canceled flow with BT's JS SDK
            if (error.code == BTPaymentFlowDriverErrorTypeCanceled) {
                NSDictionary *dictionary = @{
                    @"nonce":  threeDResultNonce,
                    @"deviceData": self.deviceDataCollector
                };
                
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                              messageAsDictionary:dictionary];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                
            } else {
                NSDictionary *dictionary = @{
                    @"nonce": threeDResultNonce,
                    @"error": [error localizedDescription]
                };
                
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                              messageAsDictionary:dictionary];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
            
            return;
        }
        
        BTThreeDSecureResult * threeDSecureResult = (BTThreeDSecureResult *)result;
        
        NSDictionary *dictionary = @{
            @"nonce":  threeDSecureResult.tokenizedCard.nonce,
            @"deviceData": self.deviceDataCollector
        };
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:dictionary];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
    }];
}

- (void)presentApplePayWithDescription:(NSString*)description amount:(NSString*)amount andRequiredShippingContactFields:(NSSet<PKContactField> *)requiredShippingContactFields {
    
    BTApplePayClient *applePayClient = [[BTApplePayClient alloc] initWithAPIClient:self.braintreeClient];
    [applePayClient paymentRequest:^(PKPaymentRequest * _Nullable paymentRequest, NSError * _Nullable error) {
        
        if (error != nil) {
            NSLog(@"Error: %@", [error localizedDescription]);
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
            dropInUIcallbackId = nil;
            
            return;
        }
        
        paymentRequest.paymentSummaryItems = @[
            [PKPaymentSummaryItem summaryItemWithLabel:description
                                                amount:[NSDecimalNumber decimalNumberWithString: amount]]
        ];
        paymentRequest.merchantIdentifier = applePayMerchantID;
        paymentRequest.currencyCode = currencyCode;
        paymentRequest.countryCode = countryCode;
        paymentRequest.supportedNetworks = supportedNetworks;
        paymentRequest.merchantCapabilities = PKMerchantCapability3DS;
        // paymentRequest.requiredBillingContactFields = [NSSet setWithArray:@[PKContactFieldName, PKContactFieldEmailAddress, PKContactFieldPhoneNumber]];
        paymentRequest.requiredShippingContactFields = requiredShippingContactFields;
        
        PKPaymentAuthorizationViewController *viewController = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:paymentRequest];
        viewController.delegate = self;
        
        applePaySuccess = NO;
        
        // display ApplePay ont the rootViewController
        UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
        
        [rootViewController presentViewController:viewController animated:YES completion:nil];
    }];
}


#pragma mark - PKPaymentAuthorizationViewControllerDelegate
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment handler:(void (^)(PKPaymentAuthorizationResult * _Nonnull))completion {
    applePaySuccess = YES;
    
    BTApplePayClient *applePayClient = [[BTApplePayClient alloc] initWithAPIClient:self.braintreeClient];
    
    NSMutableDictionary * contactInfo = [[NSMutableDictionary alloc] init];
    [contactInfo setDictionary:@{
        @"firstName": ![[[payment shippingContact] name] givenName] ? [NSNull null] : [[[payment shippingContact] name] givenName],
        @"lastName": ![[[payment shippingContact] name] familyName] ? [NSNull null] : [[[payment shippingContact] name] familyName],
        @"emailAddress": ![[payment shippingContact] emailAddress] ? [NSNull null] : [[payment shippingContact] emailAddress],
        @"phoneNumber": ![[payment shippingContact] phoneNumber] ? [NSNull null] : [[[payment shippingContact] phoneNumber] stringValue]
    }];
    
    [applePayClient tokenizeApplePayPayment:payment completion:^(BTApplePayCardNonce *tokenizedApplePayPayment, NSError *error) {
        if (tokenizedApplePayPayment) {
            // On success, send nonce to your server for processing.
            NSDictionary * paymentInfo = [self getPaymentUINonceResult:tokenizedApplePayPayment];
            
            [contactInfo addEntriesFromDictionary:paymentInfo];
            
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                          messageAsDictionary:contactInfo];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
            dropInUIcallbackId = nil;
            
            // Then indicate success or failure via the completion callback, e.g.
            completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusSuccess errors:nil]);
        } else {
            // Tokenization failed. Check `error` for the cause of the failure.
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Apple Pay tokenization failed"];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
            dropInUIcallbackId = nil;
            
            // Indicate failure via the completion callback:
            completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);
        }
    }];
    
}

- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller {
    UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    
    [rootViewController dismissViewControllerAnimated:YES completion:nil];
    
    // if not success, fire cancel event
    if (!applePaySuccess) {
        NSDictionary *dictionary = @{ @"userCancelled": @YES };
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK  messageAsDictionary:dictionary];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
        dropInUIcallbackId = nil;
    }
}


#pragma mark - BTViewControllerPresentingDelegate
- (void)paymentDriver:(id)driver requestsPresentationOfViewController:(UIViewController *)viewController {
    UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    [rootViewController presentViewController:viewController animated:YES completion:nil];
}

- (void)paymentDriver:(id)driver requestsDismissalOfViewController:(UIViewController *)viewController {
    UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    [rootViewController dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - BTThreeDSecureRequestDelegate
- (void)onLookupComplete:(BTThreeDSecureRequest *)request lookupResult:(BTThreeDSecureResult *)result next:(void(^)(void))next {
    threeDResultNonce = result.tokenizedCard.nonce;
    next();
}

*/

#pragma mark - Helpers


/**
 * Helper used to return a dictionary of values from the given payment method nonce.
 * Handles several different types of nonces (eg for cards, Apple Pay, PayPal, etc).
 */
- (NSDictionary*)dictionaryFromPaymentMethodNonce:(BTPaymentMethodNonce *)paymentMethodNonce {
//    BTCardNonce *cardNonce;
//    BTApplePayCardNonce *applePayCardNonce;
//
//    if ([paymentMethodNonce isKindOfClass:[BTCardNonce class]]) {
//        cardNonce = (BTCardNonce*)paymentMethodNonce;
//    }
//
//    if ([paymentMethodNonce isKindOfClass:[BTApplePayCardNonce class]]) {
//        applePayCardNonce = (BTApplePayCardNonce*)paymentMethodNonce;
//    }
    
    NSDictionary *dictionary = @{
        // Standard Fields
        @"nonce": paymentMethodNonce.nonce,
        @"type": paymentMethodNonce.type,
        @"isDefault": @(paymentMethodNonce.isDefault)/* ,

        @"userCancelled": @NO,

        // BTCardNonce Fields
        @"card": !cardNonce
        ? [NSNull null]
        : @{
            @"lastTwo": cardNonce.lastTwo,
            @"network": [self formatCardNetwork:cardNonce.cardNetwork]
        },
        // BTApplePayCardNonce
        @"applePayCard": !applePayCardNonce
        ? [NSNull null]
        : @{},
        
        // BTThreeDSecureCardNonce Fields
        @"deviceData": self.deviceDataCollector, */
    };
    
    return dictionary;
}

/*
- (NSArray*)mapCardTypes:(NSSet*)cardTypes {
    NSMutableArray * networks = [[NSMutableArray alloc] init];
    
    for (NSString * cardType in cardTypes) {
        PKPaymentNetwork network;
        
        if ([cardType isEqualToString:@"visa"]) {
            network = PKPaymentNetworkVisa;
        } else if ([cardType isEqualToString:@"mastercard"]) {
            network = PKPaymentNetworkMasterCard;
        } else if ([cardType isEqualToString:@"amex"]) {
            network = PKPaymentNetworkAmex;
        } else {
            NSLog(@"unsupported card type: %@", cardType);
        }
        
        if (network != nil) {
            [networks addObject:network];
        }
    }
    
    return networks;
}

- (NSSet<PKContactField>*)mapContactFields:(NSSet*)contactFields {
    NSMutableArray * fields = [[NSMutableArray alloc] init];
    
    for (NSString * contactField in contactFields) {
        PKContactField field;
        
        if ([contactField isEqualToString:@"name"]) {
            field = PKContactFieldName;
        } else if ([contactField isEqualToString:@"emailAddress"]) {
            field = PKContactFieldEmailAddress;
        } else if ([contactField isEqualToString:@"phoneNumber"]) {
            field = PKContactFieldPhoneNumber;
        } else {
            NSLog(@"unsupported contact field: %@", contactField);
        }
        
        if (field != nil) {
            [fields addObject:field];
        }
    }
    
    return [NSSet setWithArray:fields];
}
*/

/**
 * Helper used to provide a string value for the given BTCardNetwork enumeration value.
 *
- (NSString*)formatCardNetwork:(BTCardNetwork)cardNetwork {
    NSString *result = nil;
    
    // TODO: This method should probably return the same values as the Android plugin for consistency.
    
    switch (cardNetwork) {
        case BTCardNetworkUnknown:
            result = @"BTCardNetworkUnknown";
            break;
        case BTCardNetworkAMEX:
            result = @"BTCardNetworkAMEX";
            break;
        case BTCardNetworkDinersClub:
            result = @"BTCardNetworkDinersClub";
            break;
        case BTCardNetworkDiscover:
            result = @"BTCardNetworkDiscover";
            break;
        case BTCardNetworkMasterCard:
            result = @"BTCardNetworkMasterCard";
            break;
        case BTCardNetworkVisa:
            result = @"BTCardNetworkVisa";
            break;
        case BTCardNetworkJCB:
            result = @"BTCardNetworkJCB";
            break;
        case BTCardNetworkLaser:
            result = @"BTCardNetworkLaser";
            break;
        case BTCardNetworkMaestro:
            result = @"BTCardNetworkMaestro";
            break;
        case BTCardNetworkUnionPay:
            result = @"BTCardNetworkUnionPay";
            break;
        case BTCardNetworkSolo:
            result = @"BTCardNetworkSolo";
            break;
        case BTCardNetworkSwitch:
            result = @"BTCardNetworkSwitch";
            break;
        case BTCardNetworkUKMaestro:
            result = @"BTCardNetworkUKMaestro";
            break;
        default:
            result = nil;
    }
    
    return result;
}
 */

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

