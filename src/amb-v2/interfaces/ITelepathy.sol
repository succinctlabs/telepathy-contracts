// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

// A magic destinationChainId number to specify for messages that can be executed on any chain.
// Check the doc for current set of chains where the message will be executed. If any are not
// included in this set, it will still be possible to execute via self-relay.
uint32 constant BROADCAST_ALL_CHAINS = uint32(0);

enum MessageStatus {
    NOT_EXECUTED,
    EXECUTION_FAILED, // Deprecated in V2: failed handleTelepathy calls will cause the execute call to revert
    EXECUTION_SUCCEEDED
}

interface ITelepathyRouterV2 {
    event SentMessage(uint64 indexed nonce, bytes32 indexed msgHash, bytes message);

    function send(uint32 destinationChainId, bytes32 destinationAddress, bytes calldata data)
        external
        returns (bytes32);

    function send(uint32 destinationChainId, address destinationAddress, bytes calldata data)
        external
        returns (bytes32);
}

interface ITelepathyReceiverV2 {
    event ExecutedMessage(
        uint32 indexed sourceChainId,
        uint64 indexed nonce,
        bytes32 indexed msgHash,
        bytes message,
        bool success
    );

    function execute(bytes calldata _proof, bytes calldata _message) external;
}

interface ITelepathyHandlerV2 {
    function handleTelepathy(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
        external
        returns (bytes4);
}
