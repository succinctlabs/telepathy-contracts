pragma solidity 0.8.16;

import {Address, Bytes32} from "src/libraries/Typecast.sol";
import {MessageEncoding} from "src/libraries/MessageEncoding.sol";

import {SourceAMB} from "src/amb/SourceAMB.sol";
import {ITelepathyRouter, Message, ITelepathyHandler} from "src/amb/interfaces/ITelepathy.sol";

/// @title Telepathy Mock AMB for testing
/// @author Succinct Labs
/// @notice This contract is used for testing.
contract MockTelepathy is ITelepathyRouter {
    // All stuff related to sending
    uint32 chainId;
    uint64 sentNonce;
    mapping(uint32 => MockTelepathy) public telepathyReceivers;
    mapping(uint64 => Message) public sentMessages;

    // All stuff related to execution
    uint64 executedNonce;

    constructor(uint32 _chainId) {
        chainId = _chainId;
    }

    function addTelepathyReceiver(uint32 _chainId, MockTelepathy _receiver) external {
        telepathyReceivers[_chainId] = _receiver;
    }

    /// @notice SourceAMB methods

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

    function sendViaStorage(
        uint32 _destinationChainId,
        bytes32 _destinationAddress,
        bytes calldata _data
    ) external returns (bytes32) {
        return _send(_destinationChainId, _destinationAddress, _data);
    }

    function sendViaStorage(
        uint32 _destinationChainId,
        address _destinationAddress,
        bytes calldata _data
    ) external returns (bytes32) {
        return _send(_destinationChainId, Bytes32.fromAddress(_destinationAddress), _data);
    }

    /// @dev Helper methods for processing all send methods

    function _send(uint32 _destinationChainId, bytes32 _destinationAddress, bytes calldata _data)
        public
        returns (bytes32)
    {
        (Message memory message,, bytes32 messageRoot) =
            _getMessageAndRoot(_destinationChainId, _destinationAddress, _data);
        sentMessages[++sentNonce] = message;
        return messageRoot;
    }

    function _getMessageAndRoot(
        uint32 _destinationChainId,
        bytes32 _destinationAddress,
        bytes calldata _data
    ) public view returns (Message memory, bytes memory, bytes32) {
        Message memory message = Message({
            version: 1,
            nonce: sentNonce,
            sourceChainId: chainId,
            sourceAddress: msg.sender,
            destinationAddress: _destinationAddress,
            destinationChainId: _destinationChainId,
            data: _data
        });
        bytes memory messageBytes = MessageEncoding.encode(message);
        bytes32 messageRoot = keccak256(messageBytes);
        return (message, messageBytes, messageRoot);
    }

    /// @notice to execute the next message that has been sent
    function executeNextMessage() external returns (bool) {
        Message memory message = sentMessages[++executedNonce];
        MockTelepathy receiver = telepathyReceivers[message.destinationChainId];
        require(receiver != MockTelepathy(address(0)), "MockAMB: No receiver for chain");
        return receiver._executeMessage(message);
    }

    /// @dev helper method to execute the message
    function _executeMessage(Message memory message) public returns (bool) {
        bool status;
        bytes memory data;
        {
            bytes memory receiveCall = abi.encodeWithSelector(
                ITelepathyHandler.handleTelepathy.selector,
                message.sourceChainId,
                message.sourceAddress,
                message.data
            );
            address destination = Address.fromBytes32(message.destinationAddress);
            (status, data) = destination.call(receiveCall);
        }

        // Unfortunately, there are some edge cases where a call may have a successful status but
        // not have actually called the handler. Thus, we enforce that the handler must return
        // a magic constant that we can check here. To avoid stack underflow / decoding errors, we
        // only decode the returned bytes if one EVM word was returned by the call.
        bool implementsHandler = false;
        if (data.length == 32) {
            (bytes4 magic) = abi.decode(data, (bytes4));
            implementsHandler = magic == ITelepathyHandler.handleTelepathy.selector;
        }
        return status && implementsHandler;
    }
}
