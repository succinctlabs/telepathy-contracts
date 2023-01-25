pragma solidity 0.8.14;

import {TypeCasts} from "src/libraries/Typecast.sol";

import {ITelepathyBroadcaster, Message} from "./interfaces/ITelepathy.sol";

/// @title Telepathy Source Arbitrary Message Bridge
/// @author Succinct Labs
/// @notice This contract is the entrypoint for making a cross-chain call.
contract SourceAMB is ITelepathyBroadcaster {
    /// @notice Mapping between a nonce and a message root.
    mapping(uint256 => bytes32) public messages;

    /// @notice Keeps track of the next nonce to be used.
    uint256 public nonce = 1;

    /// @notice Sends a message to a target chain.
    /// @param _recipientChainId The chain id that specifies the target chain.
    /// @param _recipientAddress The contract address that will be called on the target chain.
    /// @param _data The calldata used when calling the contract on the target chain.
    /// @return bytes32 A unique identifier for a message.
    function send(uint16 _recipientChainId, bytes32 _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(_recipientChainId, _recipientAddress, _data);
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Sends a message to a target chain.
    /// @param _recipientChainId The chain id that specifies the target chain.
    /// @param _recipientAddress The contract address that will be called on the target chain.
    /// @param _data The calldata used when calling the contract on the target chain.
    /// @return bytes32 A unique identifier for a message.
    function send(uint16 _recipientChainId, address _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        (bytes memory message, bytes32 messageRoot) = _getMessageAndRoot(
            _recipientChainId, TypeCasts.addressToBytes32(_recipientAddress), _data
        );
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Sends a message to a target chain using an event log instead of a storage slot.
    /// @param _recipientChainId The chain id that specifies the target chain.
    /// @param _recipientAddress The contract address that will be called on the target chain.
    /// @param _data The calldata used when calling the contract on the target chain.
    /// @return bytes32 A unique identifier for a message.
    function sendViaLog(uint16 _recipientChainId, bytes32 _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(_recipientChainId, _recipientAddress, _data);
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Sends a message to a target chain using an event log instead of a storage slot.
    /// @param _recipientChainId The chain id that specifies the target chain.
    /// @param _recipientAddress The contract address that will be called on the target chain.
    /// @param _data The calldata used when calling the contract on the target chain.
    /// @return bytes32 A unique identifier for a message.
    function sendViaLog(uint16 _recipientChainId, address _recipientAddress, bytes calldata _data)
        external
        returns (bytes32)
    {
        (bytes memory message, bytes32 messageRoot) = _getMessageAndRoot(
            _recipientChainId, TypeCasts.addressToBytes32(_recipientAddress), _data
        );
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Gets the message and message root from the user-provided arguments to `send`
    /// @param _recipientChainId The chain id that specifies the target chain.
    /// @param _recipientAddress The contract address that will be called on the target chain.
    /// @param _data The calldata used when calling the contract on the target chain.
    /// @return messageBytes The message encoded as bytes, used in SentMessage event.
    /// @return messageRoot The hash of messageBytes, used as a unique identifier for a message.
    function _getMessageAndRoot(
        uint16 _recipientChainId,
        bytes32 _recipientAddress,
        bytes calldata _data
    ) internal view returns (bytes memory messageBytes, bytes32 messageRoot) {
        Message memory message = Message({
            nonce: nonce,
            sourceChainId: uint16(block.chainid),
            senderAddress: msg.sender,
            recipientAddress: _recipientAddress,
            recipientChainId: _recipientChainId,
            data: _data
        });
        messageBytes = abi.encode(message);
        messageRoot = keccak256(messageBytes);
    }
}
