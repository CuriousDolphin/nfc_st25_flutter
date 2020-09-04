#import "NfcSt25Plugin.h"
#if __has_include(<nfc_st25/nfc_st25-Swift.h>)
#import <nfc_st25/nfc_st25-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "nfc_st25-Swift.h"
#endif

@implementation NfcSt25Plugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftNfcSt25Plugin registerWithRegistrar:registrar];
}
@end
