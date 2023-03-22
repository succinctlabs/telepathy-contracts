pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockTelepathy} from "src/amb/mocks/MockTelepathy.sol";
import {TelepathySubscriber} from "src/pubsub/TelepathySubscriber.sol";
import {Subscription, SubscriptionStatus} from "src/pubsub/interfaces/IPubSub.sol";
import {TelepathyHandler} from "src/amb/interfaces/TelepathyHandler.sol";

contract TelepathySubscriberTest is Test {
    event Subscribe(
        bytes32 indexed subscriptionId,
        uint64 indexed startSlot,
        uint64 indexed endSlot,
        Subscription subscription
    );
    event Unsubscribe(bytes32 indexed subscriptionId, Subscription Subscription);

    MockTelepathy mockTelepathy;
    TelepathySubscriber telepathySubscriber;

    uint32 DESTINATION_CHAIN = 137;
    uint32 SOURCE_CHAIN = 1;
    address SOURCE_ADDRESS = makeAddr("Counter");
    address CALLBACK_ADDRESS = makeAddr("CounterSubscriber");
    bytes32 EVENT_SIG = keccak256("Incremented(uint256,address)");

    function setUp() public {
        mockTelepathy = new MockTelepathy(DESTINATION_CHAIN);
        telepathySubscriber = new TelepathySubscriber();
    }

    function test_Subscribe() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            uint64(0),
            uint64(0),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId = telepathySubscriber.subscribe(
            SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG, uint64(0), uint64(0)
        );
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );
    }

    function test_Subscribe_WhenBlockRangeSet() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            uint64(6000000),
            uint64(7000000),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId = telepathySubscriber.subscribe(
            SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG, uint64(6000000), 7000000
        );
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );
    }

    function test_Subscribe_WhenOnlyEndBlockSet() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            uint64(0),
            uint64(7000000),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId = telepathySubscriber.subscribe(
            SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG, uint64(0), 7000000
        );
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );
    }

    function test_SubscribeRevert_WhenOnlyStartBlockSet() public {
        vm.expectRevert(
            abi.encodeWithSignature("InvalidSlotRange(uint64,uint64)", uint64(6000000), uint64(0))
        );
        telepathySubscriber.subscribe(
            SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG, uint64(6000000), uint64(0)
        );
    }

    function test_SubscribeRevert_WhenOnlyEndBlockLowerThanStartBlock() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidSlotRange(uint64,uint64)", uint64(6000000), uint64(5000000)
            )
        );
        telepathySubscriber.subscribe(
            SOURCE_CHAIN,
            SOURCE_ADDRESS,
            CALLBACK_ADDRESS,
            EVENT_SIG,
            uint64(6000000),
            uint64(5000000)
        );
    }

    function test_SubscribeRevert_WhenDuplicate() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            uint64(0),
            uint64(0),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId = telepathySubscriber.subscribe(
            SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG, uint64(0), uint64(0)
        );
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );

        vm.expectRevert(
            abi.encodeWithSignature("SubscriptionAlreadyActive(bytes32)", subscriptionId)
        );
        telepathySubscriber.subscribe(
            SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG, uint64(0), uint64(0)
        );

        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );
    }

    function teRevert_When() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            uint64(0),
            uint64(0),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId = telepathySubscriber.subscribe(
            SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG, uint64(0), uint64(0)
        );
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );

        vm.expectEmit(true, true, true, true);
        emit Unsubscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        vm.prank(CALLBACK_ADDRESS);
        telepathySubscriber.unsubscribe(SOURCE_CHAIN, SOURCE_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.UNSUBSCIBED
        );
    }

    function test_UnsubscribeRevert_WhenDuplicate() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            uint64(0),
            uint64(0),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId = telepathySubscriber.subscribe(
            SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG, uint64(0), uint64(0)
        );
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );

        vm.expectEmit(true, true, true, true);
        emit Unsubscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        vm.prank(CALLBACK_ADDRESS);
        telepathySubscriber.unsubscribe(SOURCE_CHAIN, SOURCE_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.UNSUBSCIBED
        );

        vm.expectRevert(abi.encodeWithSignature("SubscriptionNotActive(bytes32)", subscriptionId));
        vm.prank(CALLBACK_ADDRESS);
        telepathySubscriber.unsubscribe(SOURCE_CHAIN, SOURCE_ADDRESS, EVENT_SIG);

        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.UNSUBSCIBED
        );
    }

    function test_UnsubscribeRevert_WhenFromWrongAddress() public {
        vm.expectEmit(true, true, true, true);
        emit Subscribe(
            keccak256(
                abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG))
            ),
            uint64(0),
            uint64(0),
            Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG)
        );
        bytes32 subscriptionId = telepathySubscriber.subscribe(
            SOURCE_CHAIN, SOURCE_ADDRESS, CALLBACK_ADDRESS, EVENT_SIG, uint64(0), uint64(0)
        );
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );

        bytes32 mismatchSubscriptionId =
            keccak256(abi.encode(Subscription(SOURCE_CHAIN, SOURCE_ADDRESS, msg.sender, EVENT_SIG)));
        vm.prank(msg.sender);
        vm.expectRevert(
            abi.encodeWithSignature("SubscriptionNotActive(bytes32)", mismatchSubscriptionId)
        );
        telepathySubscriber.unsubscribe(SOURCE_CHAIN, SOURCE_ADDRESS, EVENT_SIG);
        assertTrue(
            telepathySubscriber.subscriptions(subscriptionId) == SubscriptionStatus.SUBSCRIBED
        );
    }
}
