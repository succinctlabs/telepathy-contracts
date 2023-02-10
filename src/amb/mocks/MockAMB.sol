pragma solidity 0.8.14;

import {Address, Bytes32} from "src/libraries/Typecast.sol";
import {SourceAMB} from "../SourceAMB.sol";
import {ITelepathyBroadcaster, Message, ITelepathyHandler} from "../interfaces/ITelepathy.sol";

/// @title Telepathy Mock AMB for testing
/// @author Succinct Labs
/// @notice This contract is used for testing.
contract MockTelepathy is ITelepathyBroadcaster {
    // All stuff related to sending
    uint16 chainId;
    uint256 sentNonce;
    mapping(uint16 => MockTelepathy) public telepathyReceivers;
    mapping(uint256 => Message) public sentMessages;

    // All stuff related to execution
    uint256 executedNonce;

    constructor(uint16 _chainId) {
        chainId = _chainId;
    }

    function addTelepathyReceiver(uint16 _chainId, MockTelepathy _receiver) external {
        telepathyReceivers[_chainId] = _receiver;
    }

    /// @notice SourceAMB methods

    function send(uint16 _recipientChainId, bytes32 _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        return _send(_recipientChainId, _recipientAddress, _data);
    }

    function send(uint16 _recipientChainId, address _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        return _send(_recipientChainId, Bytes32.fromAddress(_recipientAddress), _data);
    }

    function sendViaLog(uint16 _recipientChainId, bytes32 _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        return _send(_recipientChainId, _recipientAddress, _data);
    }

    function sendViaLog(uint16 _recipientChainId, address _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        return _send(_recipientChainId, Bytes32.fromAddress(_recipientAddress), _data);
    }

    /// @dev Helper methods for processing all send methods

    function _send(uint16 _recipientChainId, bytes32 _recipientAddress, bytes calldata _data)
        public
        returns (bytes32)
    {
        (Message memory message,, bytes32 messageRoot) =
            _getMessageAndRoot(_recipientChainId, _recipientAddress, _data);
        sentMessages[++sentNonce] = message;
        return messageRoot;
    }

    function _getMessageAndRoot(
        uint16 _recipientChainId,
        bytes32 _recipientAddress,
        bytes calldata _data
    ) public view returns (Message memory, bytes memory, bytes32) {
        Message memory message = Message({
            nonce: sentNonce,
            sourceChainId: chainId,
            senderAddress: msg.sender,
            recipientAddress: _recipientAddress,
            recipientChainId: _recipientChainId,
            data: _data
        });
        bytes memory messageBytes = abi.encode(message);
        bytes32 messageRoot = keccak256(messageBytes);
        return (message, messageBytes, messageRoot);
    }

    /// @notice to execute the next message that has been sent
    function executeNextMessage() external returns (bool) {
        Message memory message = sentMessages[++executedNonce];
        MockTelepathy receiver = telepathyReceivers[message.recipientChainId];
        require(receiver != MockTelepathy(address(0)), "MockAMB: No receiver for chain");
        return receiver._executeMessage(message);
    }

    /// @dev helper method to execute the message
    function _executeMessage(Message memory message) public returns (bool) {
        bool status;
        bytes memory receiveCall = abi.encodeWithSelector(
            ITelepathyHandler.rawHandleTelepathy.selector,
            message.sourceChainId,
            message.senderAddress,
            message.data
        );
        address recipient = Address.fromBytes32(message.recipientAddress);
        (status,) = recipient.call(receiveCall);

        return status;
    }
}
