pragma solidity ^0.8.16;

import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";
import {ISubscriptionReceiver} from "src/pubsub/interfaces/ISubscriptionReceiver.sol";

abstract contract SubscriptionReceiver is ISubscriptionReceiver {
    TelepathyPubSub public telepathyPubSub;

    error NotFromTelepathyPubSub(address sender);

    constructor(address _telepathyPubSub) {
        telepathyPubSub = TelepathyPubSub(_telepathyPubSub);
    }

    function handlePublish(
        bytes32 _subscriptionId,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _slot,
        bytes32 _publishKey,
        bytes32[] memory _eventTopics,
        bytes memory _eventData
    ) external override returns (bytes4) {
        if (msg.sender != address(telepathyPubSub)) {
            revert NotFromTelepathyPubSub(msg.sender);
        }
        handlePublishImpl(
            _subscriptionId,
            _sourceChainId,
            _sourceAddress,
            _slot,
            _publishKey,
            _eventTopics,
            _eventData
        );
        return ISubscriptionReceiver.handlePublish.selector;
    }

    function handlePublishImpl(
        bytes32 _subscriptionId,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _slot,
        bytes32 _publishKey,
        bytes32[] memory _eventTopics,
        bytes memory _eventData
    ) internal virtual;
}
