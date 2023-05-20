pragma solidity 0.8.16;

import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

import {Bytes32} from "src/libraries/Typecast.sol";
import {MessageEncoding} from "src/libraries/MessageEncoding.sol";
import {ITelepathyRouter, Message} from "src/amb/interfaces/ITelepathy.sol";
import {TelepathyAccess} from "src/amb/TelepathyAccess.sol";
import {TelepathyStorage} from "src/amb/TelepathyStorage.sol";

/// @title Source Arbitrary Message Bridge
/// @author Succinct Labs
/// @notice This contract is the entrypoint for sending messages to other chains.
contract SourceAMB is TelepathyStorage, ITelepathyRouter {
    error SendingDisabled();
    error CannotSendToSameChain();

    /// @notice Modifier to require that sending is enabled.
    modifier isSendingEnabled() {
        if (!sendingEnabled) {
            revert SendingDisabled();
        }
        _;
    }

    /// @notice Sends a message to a destination chain.
    /// @param destinationChainId The chain id that specifies the destination chain.
    /// @param destinationAddress The contract address that will be called on the destination chain.
    /// @param data The data passed to the contract on the other chain
    /// @return bytes32 A unique identifier for a message.
    function send(uint32 destinationChainId, bytes32 destinationAddress, bytes calldata data)
        external
        isSendingEnabled
        returns (bytes32)
    {
        if (destinationChainId == block.chainid) revert CannotSendToSameChain();
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(destinationChainId, destinationAddress, data);
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    function send(uint32 destinationChainId, address destinationAddress, bytes calldata data)
        external
        isSendingEnabled
        returns (bytes32)
    {
        if (destinationChainId == block.chainid) revert CannotSendToSameChain();
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(destinationChainId, Bytes32.fromAddress(destinationAddress), data);
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Sends a message to a destination chain.
    /// @notice This method is more expensive than the `send` method as it requires adding to
    ///         contract storage. Use `send` when interacting with Telepathy to save gas.
    /// @param destinationChainId The chain id that specifies the destination chain.
    /// @param destinationAddress The contract address that will be called on the destination chain.
    /// @param data The data passed to the contract on the other chain
    /// @return bytes32 A unique identifier for a message.
    function sendViaStorage(
        uint32 destinationChainId,
        bytes32 destinationAddress,
        bytes calldata data
    ) external isSendingEnabled returns (bytes32) {
        if (destinationChainId == block.chainid) revert CannotSendToSameChain();
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(destinationChainId, destinationAddress, data);
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    function sendViaStorage(
        uint32 destinationChainId,
        address destinationAddress,
        bytes calldata data
    ) external isSendingEnabled returns (bytes32) {
        if (destinationChainId == block.chainid) revert CannotSendToSameChain();
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(destinationChainId, Bytes32.fromAddress(destinationAddress), data);
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Gets the message and message root from the user-provided arguments to `send`
    /// @param destinationChainId The chain id that specifies the destination chain.
    /// @param destinationAddress The contract address that will be called on the destination chain.
    /// @param data The calldata used when calling the contract on the destination chain.
    /// @return messageBytes The message encoded as bytes, used in SentMessage event.
    /// @return messageRoot The hash of messageBytes, used as a unique identifier for a message.
    function _getMessageAndRoot(
        uint32 destinationChainId,
        bytes32 destinationAddress,
        bytes calldata data
    ) internal view returns (bytes memory messageBytes, bytes32 messageRoot) {
        messageBytes = MessageEncoding.encode(
            version,
            nonce,
            uint32(block.chainid),
            msg.sender,
            destinationChainId,
            destinationAddress,
            data
        );
        messageRoot = keccak256(messageBytes);
    }
}
