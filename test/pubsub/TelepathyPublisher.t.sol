pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockTelepathy} from "src/amb/mocks/MockTelepathy.sol";
import {
    TelepathySubscriber,
    SubscriptionStatus,
    Subscription
} from "src/pubsub/TelepathySubscriber.sol";
import {TelepathyPublisher} from "src/pubsub/TelepathyPublisher.sol";
import {TelepathyHandler} from "src/amb/interfaces/TelepathyHandler.sol";

contract TelepathyPublisherTest is Test {
    MockTelepathy mockTelepathy;

    function setUp() public {
        mockTelepathy = new MockTelepathy(1);
    }

    function test() public {
        // TODO after implementation is finalized
    }
}
