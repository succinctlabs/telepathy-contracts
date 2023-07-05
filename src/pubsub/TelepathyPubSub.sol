pragma solidity ^0.8.16;

import {TelepathyPublisher} from "src/pubsub/TelepathyPublisher.sol";
import {TelepathySubscriber} from "src/pubsub/TelepathySubscriber.sol";
import {PubSubStorage} from "src/pubsub/PubSubStorage.sol";
import {TelepathyRouter} from "src/amb/TelepathyRouter.sol";
import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";

/// @title TelepathyPubSub
/// @author Succinct Labs
/// @notice This allows an on-chain Publisher-Suscriber model to be used for events. Contracts can subscribe to
///         events emitted from a source contract, and it will be relayed these events through the publisher. Before
///         the events are relayed, they are verified using the Telepathy Light Client for proof of consensus on the
///         source chain.
contract TelepathyPubSub is TelepathyPublisher, TelepathySubscriber {
    constructor(address _guardian, address _timelock, address _lightClient) {
        guardian = _guardian;
        timelock = _timelock;
        lightClient = ILightClient(_lightClient);
        paused = false;
    }

    modifier onlyGuardian() {
        require(msg.sender == guardian, "Only guardian");
        _;
    }

    modifier onlyTimelock() {
        require(msg.sender == timelock, "Only timelock");
        _;
    }

    function togglePause() external onlyGuardian {
        paused = !paused;
    }

    function setLightClient(address _lightClient) external onlyTimelock {
        lightClient = ILightClient(_lightClient);
    }
}
