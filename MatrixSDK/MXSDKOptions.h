/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <Foundation/Foundation.h>
#import "MXAnalyticsDelegate.h"


#pragma mark - Build time options

#pragma mark Automatic enabling
/**
 These flags are automatically enabled if the application Xcode workspace contains
 their associated Cocoa pods.
 */

/**
 Crypto.

 The crypto module depends on libolm (https://matrix.org/git/olm/ ), which the iOS wrapper
 is OLMKit:

     pod 'OLMKit'
 */
#if __has_include(<OLMKit/OLMKit.h>)
#define MX_CRYPTO
#endif


#pragma mark - Launch time options

NS_ASSUME_NONNULL_BEGIN

@protocol MXBackgroundModeHandler;

/**
 SDK options that can be set at the launch time.
 */
@interface MXSDKOptions : NSObject

+ (MXSDKOptions *)sharedInstance;

/**
 By default Matrix SDK sets an identicon url when user's avatar is undefined
 (see [MXRestClient urlOfIdenticon:] use).
 
 Use this property to disable identicon use at SDK level. NO by default.
 */
@property (nonatomic) BOOL disableIdenticonUseForUserAvatar;

/**
 Automatically enable crypto starting a new MXSession.
 NO by default.
 */
@property (nonatomic) BOOL enableCryptoWhenStartingMXSession;

/**
 Send stats to Google Analytics.

 NO by default.
 */
@property (nonatomic) BOOL enableGoogleAnalytics;

/**
 The delegate object to receive analytics events
 
 By default, nil.
 */
@property (nonatomic, nullable) id<MXAnalyticsDelegate> analyticsDelegate;

/**
 The version of the media cache at the application level.
 By updating this value the application is able to clear the existing media cache.
 
 The default version value is 0.
 */
@property (nonatomic) NSUInteger mediaCacheAppVersion;

/**
 Object that handle enabling background mode
 */
@property (nonatomic) id<MXBackgroundModeHandler> backgroundModeHandler;

/**
 The App Group identifier.
 Specify this value if you want to share data with app extensions.
 
 nil by default.
*/
@property (nonatomic, nullable) NSString *applicationGroupIdentifier;

@end

NS_ASSUME_NONNULL_END
