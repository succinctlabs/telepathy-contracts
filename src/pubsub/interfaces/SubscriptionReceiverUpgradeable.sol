pragma solidity ^0.8.16;

import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";
import {ISubscriptionReceiver} from "src/pubsub/interfaces/ISubscriptionReceiver.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract SubscriptionReceiverUpgradeable is ISubscriptionReceiver, Initializable {
    TelepathyPubSub public telepathyPubSub;

    error NotFromTelepathyPubSub(address sender);

    function __SubscriptionReceiver_init(address _telepathyPubSub) public onlyInitializing {
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
