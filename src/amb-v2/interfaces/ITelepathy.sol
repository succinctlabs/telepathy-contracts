// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

enum MessageStatus {
    NOT_EXECUTED,
    EXECUTION_FAILED,
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
        bool status
    );

    function execute(bytes calldata _proof, bytes calldata _message) external;
}

interface ITelepathyHandlerV2 {
    function handleTelepathy(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
        external
        returns (bytes4);
}
