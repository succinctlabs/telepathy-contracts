pragma solidity ^0.8.16;

import {TelepathyPubSub} from "src/pubsub/TelepathyPubSub.sol";
import {SubscriptionReceiver} from "src/pubsub/interfaces/SubscriptionReceiver.sol";

/// @notice Example counter deployed on the source chain to listen to.
/// @dev Importantly, this contract does not need any special logic to handle it's events being subscribed to.
contract Counter {
    uint256 public count = 0;

    event Incremented(uint256 indexed count, address incrementor);
    event Decremented(uint256 indexed count, address decrementor);

    function increment() external {
        count += 1;
        emit Incremented(count, msg.sender);
    }

    function decrement() external {
        count -= 1;
        emit Decremented(count, msg.sender);
    }
}

/// @notice This contract is used to subscribe to a cross-chain events from a source Counter on a different chain.
///     It demonstrates how you can handle multiple event emits from a single source contract you're subscribed to.
/// @dev You could also maintain a list of multiple Counter contracts across multiple chains.
contract CounterSubscriber is SubscriptionReceiver {
    event CrossChainIncremented(uint256 indexed count, address incrementor);
    event CrossChainDecremented(uint256 indexed count, address decrementor);

    error InvalidSourceChain(uint32 sourceChainId);
    error InvalidSourceAddress(address sourceAddress);
    error InvalidSlot(uint64 slot);
    error InvalidSubscriptionId(bytes32 subscriptionId);
    error InvalidEventSig(bytes32 eventSig);

    bytes32 constant INCREMENT_EVENT_SIG = keccak256("Incremented(uint256,address)");
    bytes32 constant DECREMENT_EVENT_SIG = keccak256("Decremented(uint256,address)");

    uint32 immutable EVENT_SOURCE_CHAIN_ID;
    address immutable EVENT_SOURCE_ADDRESS;
    uint64 immutable START_SLOT;
    uint64 immutable END_SLOT;

    mapping(bytes32 => bool) activeSubscriptions;

    constructor(
        address _telepathyPubSub,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _startSlot,
        uint64 _endSlot
    ) SubscriptionReceiver(_telepathyPubSub) {
        EVENT_SOURCE_CHAIN_ID = _sourceChainId;
        EVENT_SOURCE_ADDRESS = _sourceAddress;
        START_SLOT = _startSlot;
        END_SLOT = _endSlot;
    }

    function subscribeToIncEvent(uint32 _sourceChainId, address _sourceAddress) external {
        bytes32 subscriptionId = telepathyPubSub.subscribe(
            _sourceChainId, _sourceAddress, address(this), INCREMENT_EVENT_SIG, START_SLOT, END_SLOT
        );
        activeSubscriptions[subscriptionId] = true;
    }

    function unsubscribeFromIncEvent(uint32 _sourceChainId, address _sourceAddress) external {
        bytes32 subscriptionId =
            telepathyPubSub.unsubscribe(_sourceChainId, _sourceAddress, INCREMENT_EVENT_SIG);
        activeSubscriptions[subscriptionId] = false;
    }

    function subscribeToDecEvent(uint32 _sourceChainId, address _sourceAddress) external {
        bytes32 subscriptionId = telepathyPubSub.subscribe(
            _sourceChainId, _sourceAddress, address(this), DECREMENT_EVENT_SIG, START_SLOT, END_SLOT
        );
        activeSubscriptions[subscriptionId] = true;
    }

    function unsubscribeFromDecEvent(uint32 _sourceChainId, address _sourceAddress) external {
        bytes32 subscriptionId =
            telepathyPubSub.unsubscribe(_sourceChainId, _sourceAddress, DECREMENT_EVENT_SIG);
        activeSubscriptions[subscriptionId] = false;
    }

    function handlePublishImpl(
        bytes32 _subscriptionId,
        uint32 _sourceChainId,
        address _sourceAddress,
        uint64 _slot,
        bytes32[] memory eventTopics,
        bytes memory eventdata
    ) internal override {
        if (_sourceChainId != EVENT_SOURCE_CHAIN_ID) {
            revert InvalidSourceChain(_sourceChainId);
        }

        if (_sourceAddress != EVENT_SOURCE_ADDRESS) {
            revert InvalidSourceAddress(_sourceAddress);
        }

        if (_slot < START_SLOT || _slot > END_SLOT) {
            revert InvalidSlot(_slot);
        }

        if (!activeSubscriptions[_subscriptionId]) {
            revert InvalidSubscriptionId(_subscriptionId);
        }

        // Implement arbitrary logic to handle the publish.
        // In this case, we are just emitting our own event in response to the source Counter.

        bytes32 eventSig = eventTopics[0];
        uint256 count = uint256(eventTopics[1]);
        if (eventSig == INCREMENT_EVENT_SIG) {
            emit CrossChainIncremented(count, abi.decode(eventdata, (address)));
        } else if (eventSig == DECREMENT_EVENT_SIG) {
            emit CrossChainDecremented(count, abi.decode(eventdata, (address)));
        }
    }
}
