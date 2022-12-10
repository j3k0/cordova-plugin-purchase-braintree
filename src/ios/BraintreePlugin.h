//
//  BraintreePlugin.h
//

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>
#import <BraintreeDropIn/BraintreeDropIn.h>

@interface BraintreePlugin : CDVPlugin
- (void) launchDropIn:(CDVInvokedUrlCommand * _Nonnull)command;
- (void) setLogger:(CDVInvokedUrlCommand * _Nonnull)command;
- (void) setVerbosity:(CDVInvokedUrlCommand* _Nonnull)command;

/// Returns the braintree API client created by DropIn
///
/// It's only available after "launchDropIn" is done.
+ (BTAPIClient* _Nullable) getClient;

/// Helper for parsing cordova dictionaries
/// this returns a boolean, or the default value when it's not present in the dictionary.
+ (BOOL)boolIn:(NSDictionary* _Nullable)options forKey:(NSString* _Nonnull)key withDefault:(BOOL)defaultValue;
/// This returns the string from the dictionary.
+ (NSString* _Nullable)stringIn:(NSDictionary* _Nullable)options forKey:(NSString* _Nonnull)key;
/// This returns a decimal number, it should be passed as a string.
+ (NSDecimalNumber* _Nullable)decimalNumberIn:(NSDictionary* _Nullable)options forKey:(NSString* _Nonnull)key;
/// This returns an NSDate, it should be passed as a number of milliseconds since epoch.
+ (NSDate* _Nullable)dateIn:(NSDictionary* _Nullable)options forKey:(NSString* _Nonnull)key;
/// This returns an NSCalendarUnit from an IPeriodUnit.
+ (NSCalendarUnit)calendarUnitIn:(NSDictionary* _Nullable)options forKey:(NSString* _Nonnull)key withDefault:(NSCalendarUnit)defaultValue;
@end
