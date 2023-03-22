pragma solidity ^0.8.16;

/// @notice The possible states a subscription can be in.
enum SubscriptionStatus {
    UNSUBSCIBED,
    SUBSCRIBED
}

/// @notice Represents an active subscription, specific to the combination of all of the parameters.
/// @param sourceChainId The chain ID of the source contract.
/// @param sourceAddress The address of the source contract which emits the target event.
/// @param callbackAddress The address of the contract which will receive the event data. MUST be implement
///     the ISubscriptionCallbackReceiver interface.
/// @param eventSig The signature of the event to listen for.
/// @dev A subscription will still be active even if the endSlot has passed. To renew a subscription
///     with different slot ranges, unsubscribe and re-subscribe. The reason slot ranges are not included
///     in this struct is because they shouldn't influence the subscriptionId -- otherwise a subscriber could
///     have overlapping subscriptions on the same event.
struct Subscription {
    uint32 sourceChainId;
    address sourceAddress;
    address callbackAddress;
    bytes32 eventSig;
}

interface ISubscriber {
    /// @notice Emitted when a new subscription is created.
    /// @param subscriptionId The unique identifier for the subscription.
    /// @param startSlot The Beacon Chain slot to start listening for events, 0 for all slots up to endSlot.
    /// @param endSlot The Beacon Chain slot to stop listening for events, 0 for no limit.
    /// @param subscription The subscription details.
    /// @dev The startSlot and endSlot are inclusive.
    event Subscribe(
        bytes32 indexed subscriptionId,
        uint64 indexed startSlot,
        uint64 indexed endSlot,
        Subscription subscription
    );

    /// @notice Emitted when a subscription is cancelled.
    /// @param subscriptionId The unique identifier for the subscription.
    /// @param subscription The subscription details.
    event Unsubscribe(bytes32 indexed subscriptionId, Subscription subscription);

    function subscribe(
        uint32 sourceChainId,
        address sourceAddress,
        address callbackAddress,
        bytes32 eventSig,
        uint64 startSlot,
        uint64 endSlot
    ) external returns (bytes32 subscriptionId);

    function unsubscribe(uint32 sourceChainId, address sourceAddress, bytes32 eventSig)
        external
        returns (bytes32 subscriptionId);
}

enum PublishStatus {
    NOT_EXECUTED,
    EXECUTION_FAILED,
    EXECUTION_SUCCEEDED
}

interface IPublisher {
    /// @notice Emitted when an event is published for a given subscription.
    /// @param subscriptionId The unique identifier for the subscription.
    /// @param sourceChainId The chain ID of the source contract.
    /// @param sourceAddress The address of the source contract which emitted the target event.
    /// @param callbackAddress The address of the contract which received the event data.
    /// @param success True if the callbackAddress successfully recieved the publish, false otherwise.
    event Publish(
        bytes32 indexed subscriptionId,
        uint32 indexed sourceChainId,
        address indexed sourceAddress,
        address callbackAddress,
        bool success
    );

    function publishEvent(
        bytes calldata srcSlotTxSlotPack,
        bytes32[] calldata receiptsRootProof,
        bytes32 receiptsRoot,
        bytes[] calldata receiptProof,
        bytes memory txIndexRLPEncoded,
        uint256 logIndex,
        Subscription calldata subscription
    ) external;
}
