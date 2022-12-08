//
//  BraintreePlugin.h
//

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>
#import <BraintreeDropIn/BraintreeDropIn.h>

@interface BraintreePlugin : CDVPlugin
- (void) launchDropIn:(CDVInvokedUrlCommand *)command;
- (void) setLogger:(CDVInvokedUrlCommand *)command;
- (void) setVerbosity:(CDVInvokedUrlCommand*)command;

/// Returns the braintree API client created by DropIn
///
/// It's only available after "launchDropIn" is done.
+ (BTAPIClient*) getClient;

/// Helper for parsing cordova dictionaries
/// this returns a boolean, or the default value when it's not present in the dictionary.
+ (BOOL)boolIn:(NSDictionary*)options forKey:(NSString*)key withDefault:(BOOL)defaultValue;
/// This returns the string from the dictionary.
+ (NSString*)stringIn:(NSDictionary*)options forKey:(NSString*)key;
/// This returns a decimal number, it should be passed as a string.
+ (NSDecimalNumber*)decimalNumberIn:(NSDictionary*)options forKey:(NSString*)key;
/// This returns an NSDate, it should be passed as a number of milliseconds since epoch.
+ (NSDate*)dateIn:(NSDictionary*)options forKey:(NSString*)key;
/// This returns an NSCalendarUnit from an IPeriodUnit.
+ (NSCalendarUnit)calendarUnitIn:(NSDictionary*)options forKey:(NSString*)key withDefault:(NSCalendarUnit)defaultValue;
@end
