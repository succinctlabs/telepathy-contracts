pragma solidity ^0.8.16;

import {TelepathyPublisher} from "src/pubsub/TelepathyPublisher.sol";

import {TelepathySubscriber} from "src/pubsub/TelepathySubscriber.sol";

import {PubSubStorage} from "src/pubsub/PubSubStorage.sol";

import {TelepathyRouter} from "src/amb/TelepathyRouter.sol";

// TODO: This (and Oracle Fulfiller) probably should have access control so the TelepathyRouter reference can be set again.

/// @title TelepathyPubSub
/// @author Succinct Labs
/// @notice This allows an on-chain Publisher-Suscriber model to be used for events. Contracts can subscribe to
///         events emitted from a source contract, and it will be relayed these events through the publisher. Before
///         the events are relayed, they are verified using the Telepathy Light Client for proof of consensus on the
///         source chain.
contract TelepathyPubSub is TelepathyPublisher, TelepathySubscriber {
    uint8 public constant VERSION = 1;

    constructor(address _telepathyRouter) {
        telepathyRouter = TelepathyRouter(_telepathyRouter);
    }

    // This contract is mostly just a placeholder which follows the same TelepathyRouter pattern. In the future it can
    // be modified to handle upgradability.
}
