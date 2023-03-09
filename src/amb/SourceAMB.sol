pragma solidity 0.8.16;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

import {Bytes32} from "src/libraries/Typecast.sol";
import {MessageEncoding} from "src/libraries/MessageEncoding.sol";
import {ITelepathyRouter, Message} from "./interfaces/ITelepathy.sol";
import {TelepathyAccess} from "./TelepathyAccess.sol";
import {TelepathyStorage} from "./TelepathyStorage.sol";

/// @title Source Arbitrary Message Bridge
/// @author Succinct Labs
/// @notice This contract is the entrypoint for sending messages to other chains.
contract SourceAMB is TelepathyStorage, ITelepathyRouter {
    /// @notice Modifier to require that sending is enabled.
    modifier isSendingEnabled() {
        require(sendingEnabled, "Sending is disabled");
        _;
    }

    /// @notice Sends a message to a target chain.
    /// @param recipientChainId The chain id that specifies the target chain.
    /// @param recipientAddress The contract address that will be called on the target chain.
    /// @param data The data passed to the contract on the other chain
    /// @return bytes32 A unique identifier for a message.
    function send(uint32 recipientChainId, bytes32 recipientAddress, bytes calldata data)
        external
        isSendingEnabled
        returns (bytes32)
    {
        require(recipientChainId != block.chainid, "Cannot send to same chain");
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(recipientChainId, recipientAddress, data);
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    function send(uint32 recipientChainId, address recipientAddress, bytes calldata data)
        external
        isSendingEnabled
        returns (bytes32)
    {
        require(recipientChainId != block.chainid, "Cannot send to same chain");
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(recipientChainId, Bytes32.fromAddress(recipientAddress), data);
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Sends a message to a target chain.
    /// @notice This method is more expensive than the `send` method as it requires adding to
    ///         contract storage. Use `send` when interacting with Telepathy to save gas.
    /// @param recipientChainId The chain id that specifies the target chain.
    /// @param recipientAddress The contract address that will be called on the target chain.
    /// @param data The data passed to the contract on the other chain
    /// @return bytes32 A unique identifier for a message.
    function sendViaStorage(uint32 recipientChainId, bytes32 recipientAddress, bytes calldata data)
        external
        isSendingEnabled
        returns (bytes32)
    {
        require(recipientChainId != block.chainid, "Cannot send to same chain");
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(recipientChainId, recipientAddress, data);
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    function sendViaStorage(uint32 recipientChainId, address recipientAddress, bytes calldata data)
        external
        isSendingEnabled
        returns (bytes32)
    {
        require(recipientChainId != block.chainid, "Cannot send to same chain");
        (bytes memory message, bytes32 messageRoot) =
            _getMessageAndRoot(recipientChainId, Bytes32.fromAddress(recipientAddress), data);
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Gets the message and message root from the user-provided arguments to `send`
    /// @param recipientChainId The chain id that specifies the target chain.
    /// @param recipientAddress The contract address that will be called on the target chain.
    /// @param data The calldata used when calling the contract on the target chain.
    /// @return messageBytes The message encoded as bytes, used in SentMessage event.
    /// @return messageRoot The hash of messageBytes, used as a unique identifier for a message.
    function _getMessageAndRoot(
        uint32 recipientChainId,
        bytes32 recipientAddress,
        bytes calldata data
    ) internal view returns (bytes memory messageBytes, bytes32 messageRoot) {
        messageBytes = MessageEncoding.encode(
            version,
            nonce,
            uint32(block.chainid),
            msg.sender,
            recipientChainId,
            recipientAddress,
            data
        );
        messageRoot = keccak256(messageBytes);
    }
}
