/*
 Copyright 2015 OpenMarket Ltd

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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "MatrixSDKTestsData.h"
#import "MXSession.h"

// Do not bother with retain cycles warnings in tests
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"

@interface MXNotificationCenterTests : XCTestCase
{
    MXSession *mxSession;
}

@end

@implementation MXNotificationCenterTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown {
    if (mxSession)
    {
        [[MatrixSDKTestsData sharedData] closeMXSession:mxSession];
        mxSession = nil;
    }
    [super tearDown];
}

- (void)testNotificationCenterRulesReady
{
    [[MatrixSDKTestsData sharedData] doMXRestClientTestWithBob:self readyToTest:^(MXRestClient *bobRestClient, XCTestExpectation *expectation) {

        mxSession = [[MXSession alloc] initWithMatrixRestClient:bobRestClient];

        XCTAssertNotNil(mxSession.notificationCenter);
        XCTAssertNil(mxSession.notificationCenter.rules);
        XCTAssertNil(mxSession.notificationCenter.flatRules);

        [mxSession start:^{

            XCTAssertNotNil(mxSession.notificationCenter.rules, @"Notification rules must be ready once MXSession is started");

            XCTAssertNotNil(mxSession.notificationCenter.flatRules, @"Notification rules must be ready once MXSession is started");

            XCTAssertGreaterThanOrEqual(mxSession.notificationCenter.flatRules.count, 3, @"Home server defines 3 default rules (at least)");

            [expectation fulfill];

        } failure:^(NSError *error) {
            NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
        }];
    }];
}

- (void)testNoNotificationsOnUserEvents
{
    [[MatrixSDKTestsData sharedData] doMXSessionTestWithBobAndARoomWithMessages:self readyToTest:^(MXSession *mxSession2, MXRoom *room, XCTestExpectation *expectation) {

        mxSession = mxSession2;

        [mxSession.notificationCenter listenToNotifications:^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule) {

            XCTFail(@"Events from the user should not be notified. event: %@\n rule: %@", event, rule);

        }];

        [room sendTextMessage:@"This message should not generate a notification" success:^(NSString *eventId) {

            // Wait to check that no notification happens
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

                [expectation fulfill];

            });

        } failure:^(NSError *error) {
            NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
        }];
    }];
}

- (void)testNoNotificationsOnPresenceOrTypingEvents
{
    [[MatrixSDKTestsData sharedData] doMXSessionTestWithBobAndAliceInARoom:self readyToTest:^(MXSession *bobSession, MXRestClient *aliceRestClient, NSString *roomId, XCTestExpectation *expectation) {

        mxSession = bobSession;

        [bobSession.notificationCenter listenToNotifications:^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule) {

            XCTFail(@"Presence and typing events should not be notified with default push rules. event: %@\n rule: %@", event, rule);

            [expectation fulfill];
        }];

        [aliceRestClient setPresence:MXPresenceOnline andStatusMessage:nil success:^{

            [aliceRestClient sendTypingNotificationInRoom:roomId typing:YES timeout:30000 success:^{

                // Wait to check that no notification happens
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

                    [expectation fulfill];
                    
                });

            } failure:^(NSError *error) {
                NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
            }];

        } failure:^(NSError *error) {
            NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
        }];
        
    }];
}

// The HS defines a default underride rule asking to notify for all messages of other users.
// As per SYN-267, the HS does not list it when calling GET /pushRules/.
// While this ticket is not fixed, make sure the SDK workrounds it
- (void)testDefaultPushOnAllNonYouMessagesRule
{
    [[MatrixSDKTestsData sharedData] doMXSessionTestWithBobAndAliceInARoom:self readyToTest:^(MXSession *bobSession, MXRestClient *aliceRestClient, NSString *roomId, XCTestExpectation *expectation) {

        mxSession = bobSession;

        MXRoom *room = [mxSession roomWithRoomId:roomId];
        [room listenToEventsOfTypes:@[kMXEventTypeStringRoomMember] onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState) {

            [bobSession.notificationCenter listenToNotifications:^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule) {

                // We must be alerted by the default content HS rule on any message
                XCTAssertEqual(rule.kind, MXPushRuleKindUnderride);
                XCTAssert(rule.isDefault, @"The rule must be the server default rule. Rule: %@", rule);

                [expectation fulfill];
            }];

            [aliceRestClient sendTextMessageToRoom:roomId text:@"a message" success:^(NSString *eventId) {

            } failure:^(NSError *error) {
                NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
            }];

        }];

        // Make sure there 3 are peoples in the room to avoid to fire the default "room_member_count == 2" rule
        NSString *carolId = [aliceRestClient.credentials.userId stringByReplacingOccurrencesOfString:@"mxAlice" withString:@"@mxCarol"];
        [room inviteUser:carolId success:^{

        } failure:^(NSError *error) {
            NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
        }];
    }];
};

- (void)testDefaultContentCondition
{
    [[MatrixSDKTestsData sharedData] doMXSessionTestWithBobAndAliceInARoom:self readyToTest:^(MXSession *bobSession, MXRestClient *aliceRestClient, NSString *roomId, XCTestExpectation *expectation) {

        mxSession = bobSession;

        MXRoom *room = [mxSession roomWithRoomId:roomId];
        [room listenToEventsOfTypes:@[kMXEventTypeStringRoomMember] onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState) {

            NSString *messageFromAlice = @"mxBob: you should be notified for this message";

            [bobSession.notificationCenter listenToNotifications:^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule) {

                // We must be alerted by the default content HS rule on "mxBob"
                XCTAssertEqual(rule.kind, MXPushRuleKindContent);
                XCTAssert(rule.isDefault, @"The rule must be the server default rule. Rule: %@", rule);
                XCTAssertEqualObjects(rule.pattern, @"mxBob", @"As content rule, the pattern must be define. Rule: %@", rule);

                // Check the right event has been notified
                XCTAssertEqualObjects(event.content[@"body"], messageFromAlice, @"The wrong messsage has been caught. event: %@", event);

                [expectation fulfill];
            }];


            [aliceRestClient sendTextMessageToRoom:roomId text:messageFromAlice success:^(NSString *eventId) {

            } failure:^(NSError *error) {
                NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
            }];
        }];

        // Make sure there 3 are peoples in the room to avoid to fire the default "room_member_count == 2" rule
        NSString *carolId = [aliceRestClient.credentials.userId stringByReplacingOccurrencesOfString:@"mxAlice" withString:@"@mxCarol"];
        [room inviteUser:carolId success:^{

        } failure:^(NSError *error) {
            NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
        }];
        
    }];
}

- (void)testDefaultDisplayNameCondition
{
    [[MatrixSDKTestsData sharedData] doMXSessionTestWithBobAndAliceInARoom:self readyToTest:^(MXSession *bobSession, MXRestClient *aliceRestClient, NSString *roomId, XCTestExpectation *expectation) {

        mxSession = bobSession;

        MXSession *aliceSession = [[MXSession alloc] initWithMatrixRestClient:aliceRestClient];
        [aliceSession start:^{

            // Change alice name
            [aliceSession.myUser setDisplayName:@"AALLIICCEE" success:^{

                NSString *messageFromBob = @"Aalliiccee: where are you?";

                [aliceSession.notificationCenter listenToNotifications:^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule) {

                    XCTAssertEqual(rule.kind, MXPushRuleKindOverride);

                    MXPushRuleCondition *condition = rule.conditions[0];

                    XCTAssertEqualObjects(condition.kind, kMXPushRuleConditionStringContainsDisplayName, @"The default content rule with contains_display_name condition must fire first");
                    XCTAssertEqual(condition.kindType, MXPushRuleConditionTypeContainsDisplayName);

                    [aliceSession close];
                    [expectation fulfill];

                }];

                MXRoom *roomBobSide = [mxSession roomWithRoomId:roomId];
                [roomBobSide sendTextMessage:messageFromBob success:^(NSString *eventId) {

                } failure:^(NSError *error) {
                    NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
                }];

            } failure:^(NSError *error) {
                NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
            }];

        } failure:^(NSError *error) {
            NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
        }];

    }];
}

- (void)testDefaultRoomMemberCountCondition
{
    [[MatrixSDKTestsData sharedData] doMXSessionTestWithBobAndAliceInARoom:self readyToTest:^(MXSession *bobSession, MXRestClient *aliceRestClient, NSString *roomId, XCTestExpectation *expectation) {

        mxSession = bobSession;

        NSString *messageFromAlice = @"We are two peoples in this room";

        [bobSession.notificationCenter listenToNotifications:^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule) {

            // We must be alerted by the default content HS rule on room_member_count == 2
            XCTAssertEqual(rule.kind, MXPushRuleKindOverride);
            XCTAssert(rule.isDefault, @"The rule must be the server default rule. Rule: %@", rule);

            MXPushRuleCondition *condition = rule.conditions[0];
            XCTAssertEqualObjects(condition.kind, kMXPushRuleConditionStringRoomMemberCount, @"The default content rule with room_member_count condition must fire first");
            XCTAssertEqual(condition.kindType, MXPushRuleConditionTypeRoomMemberCount);

            // Check the right event has been notified
            XCTAssertEqualObjects(event.content[@"body"], messageFromAlice, @"The wrong messsage has been caught. event: %@", event);

            [expectation fulfill];
        }];


        [aliceRestClient sendTextMessageToRoom:roomId text:messageFromAlice success:^(NSString *eventId) {

        } failure:^(NSError *error) {
            NSAssert(NO, @"Cannot set up intial test conditions - error: %@", error);
        }];
        
    }];
}

@end

#pragma clang diagnostic pop