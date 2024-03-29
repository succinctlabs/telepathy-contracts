pragma solidity ^0.8.16;

interface ISubscriptionReceiver {
    function handlePublish(
        bytes32 subscriptionId,
        uint32 sourceChainId,
        address sourceAddress,
        uint64 slot,
        bytes32 publishKey,
        bytes32[] memory eventTopics,
        bytes memory eventData
    ) external returns (bytes4);
}
