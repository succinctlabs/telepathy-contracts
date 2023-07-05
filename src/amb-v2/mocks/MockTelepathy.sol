// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {Address, Bytes32} from "src/libraries/Typecast.sol";
import {Message} from "src/libraries/Message.sol";
import {SourceAMBV2} from "src/amb-v2/SourceAMB.sol";
import {
    BROADCAST_ALL_CHAINS,
    ITelepathyRouterV2,
    ITelepathyHandlerV2
} from "src/amb-v2/interfaces/ITelepathy.sol";

/// @title Telepathy Mock AMB for testing
/// @author Succinct Labs
/// @notice This contract is used for testing.
contract MockTelepathyV2 is ITelepathyRouterV2 {
    // All stuff related to sending
    uint8 public constant version = 1;
    uint32 chainId;
    uint64 sentNonce;
    mapping(uint32 => MockTelepathyV2) public telepathyReceivers;
    mapping(uint64 => bytes) public sentMessages;

    // All stuff related to execution
    uint64 executedNonce;

    constructor(uint32 _chainId) {
        chainId = _chainId;
    }

    function addTelepathyReceiver(uint32 _chainId, MockTelepathyV2 _receiver) external {
        telepathyReceivers[_chainId] = _receiver;
    }

    /// @notice SourceAMBV2 methods

    function send(uint32 _destinationChainId, bytes32 _destinationAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        return _send(_destinationChainId, _destinationAddress, _data);
    }

    function send(uint32 _destinationChainId, address _destinationAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        return _send(_destinationChainId, Bytes32.fromAddress(_destinationAddress), _data);
    }

    /// @dev Helper methods for processing all send methods

    function _send(uint32 _destinationChainId, bytes32 _destinationAddress, bytes calldata _data)
        internal
        returns (bytes32)
    {
        (bytes memory message, bytes32 messageId) =
            _getMessageAndId(_destinationChainId, _destinationAddress, _data);
        sentMessages[++sentNonce] = message;
        return messageId;
    }

    function _getMessageAndId(
        uint32 _destinationChainId,
        bytes32 _destinationAddress,
        bytes calldata _data
    ) internal view returns (bytes memory message, bytes32 messageId) {
        message = Message.encode(
            version, sentNonce, chainId, msg.sender, _destinationChainId, _destinationAddress, _data
        );
        messageId = Message.getId(message);
    }

    /// @notice Execute the next message that has been sent.
    function executeNextMessage() external returns (bool) {
        bytes memory message = sentMessages[++executedNonce];
        MockTelepathyV2 receiver = telepathyReceivers[Message.destinationChainId(message)];
        require(receiver != MockTelepathyV2(address(0)), "MockAMB: No receiver for chain");
        return receiver.executeMessage(message);
    }

    /// @notice Execute the next message that has been sent.
    /// @param _destinationChainId which chain to execute the message on. Must be the same
    ///        as the destinationChainId of the message if BROADCAST_ALL_CHAINS wasn't used.
    function executeNextMessage(uint32 _destinationChainId) external returns (bool) {
        bytes memory message = sentMessages[++executedNonce];
        require(
            Message.destinationChainId(message) == BROADCAST_ALL_CHAINS
                || Message.destinationChainId(message) == _destinationChainId,
            "MockAMB: Message not for chain"
        );
        MockTelepathyV2 receiver = telepathyReceivers[_destinationChainId];
        require(receiver != MockTelepathyV2(address(0)), "MockAMB: No receiver for chain");
        return receiver.executeMessage(message);
    }

    /// @dev helper method to execute the message
    function executeMessage(bytes memory message) public returns (bool) {
        bool status;
        bytes memory data;
        {
            bytes memory receiveCall = abi.encodeWithSelector(
                ITelepathyHandlerV2.handleTelepathy.selector,
                Message.sourceChainId(message),
                Message.sourceAddress(message),
                Message.data(message)
            );
            address destination = Address.fromBytes32(Message.destinationAddress(message));
            (status, data) = destination.call(receiveCall);
        }

        // Unfortunately, there are some edge cases where a call may have a successful status but
        // not have actually called the handler. Thus, we enforce that the handler must return
        // a magic constant that we can check here. To avoid stack underflow / decoding errors, we
        // only decode the returned bytes if one EVM word was returned by the call.
        bool implementsHandler = false;
        if (data.length == 32) {
            (bytes4 magic) = abi.decode(data, (bytes4));
            implementsHandler = magic == ITelepathyHandlerV2.handleTelepathy.selector;
        }
        return status && implementsHandler;
    }
}
