pragma solidity ^0.8.16;

import {Subscription, SubscriptionStatus, ISubscriber} from "src/pubsub/interfaces/IPubSub.sol";

import {PubSubStorage} from "src/pubsub/PubSubStorage.sol";

/// @title TelepathySubscriber
/// @author Succinct Labs
/// @notice This allows contracts to subscribe to cross-chain events from a source contract.
contract TelepathySubscriber is ISubscriber, PubSubStorage {
    error SubscriptionAlreadyActive(bytes32 subscriptionId);
    error SubscriptionNotActive(bytes32 subscriptionId);
    error InvalidSlotRange(uint64 startSlot, uint64 endSlot);

    /// @dev The block ranges use as a signal to off-chain, and are NOT enforced by the publisher.
    ///     If events should only a certain range should be valid, the callbackAddress should do their
    ///     own validation when handling the publish.
    function subscribe(
        uint32 _sourceChainId,
        address _sourceAddress,
        address _callbackAddress,
        bytes32 _eventSig,
        uint64 _startSlot,
        uint64 _endSlot
    ) external returns (bytes32) {
        Subscription memory subscription =
            Subscription(_sourceChainId, _sourceAddress, _callbackAddress, _eventSig);
        bytes32 subscriptionId = keccak256(abi.encode(subscription));

        if (subscriptions[subscriptionId] == SubscriptionStatus.SUBSCRIBED) {
            revert SubscriptionAlreadyActive(subscriptionId);
        }
        subscriptions[subscriptionId] = SubscriptionStatus.SUBSCRIBED;

        // Either both block's slots are 0, or endSlot is must greater than startSlot.
        if (_endSlot < _startSlot) {
            revert InvalidSlotRange(_startSlot, _endSlot);
        }

        emit Subscribe(subscriptionId, _startSlot, _endSlot, subscription);

        return subscriptionId;
    }

    /// @dev Only the original callbackAddress contract will be able to unsubscribe.
    function unsubscribe(uint32 _sourceChainId, address _sourceAddress, bytes32 _eventSig)
        external
        returns (bytes32)
    {
        Subscription memory subscription =
            Subscription(_sourceChainId, _sourceAddress, msg.sender, _eventSig);
        bytes32 subscriptionId = keccak256(abi.encode(subscription));

        if (subscriptions[subscriptionId] == SubscriptionStatus.UNSUBSCIBED) {
            revert SubscriptionNotActive(subscriptionId);
        }
        subscriptions[subscriptionId] = SubscriptionStatus.UNSUBSCIBED;

        emit Unsubscribe(subscriptionId, subscription);

        return subscriptionId;
    }
}
