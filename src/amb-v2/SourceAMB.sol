// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {Bytes32} from "src/libraries/Typecast.sol";
import {Message} from "src/libraries/Message.sol";
import {ITelepathyRouterV2} from "src/amb-v2/interfaces/ITelepathy.sol";
import {TelepathyStorageV2} from "src/amb-v2/TelepathyStorage.sol";
import {MerkleProof} from "src/libraries/MerkleProof.sol";

/// @title Source Arbitrary Message Bridge
/// @author Succinct Labs
/// @notice This contract is the entrypoint for sending messages to other chains.
contract SourceAMBV2 is TelepathyStorageV2, ITelepathyRouterV2 {
    using Message for bytes;

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
    /// @param _destinationChainId The chain id that specifies the destination chain.
    /// @param _destinationAddress The contract address that will be called on the destination
    ///        chain.
    /// @param _data The data passed to the contract on the other chain
    /// @return messageId A unique identifier for a message.
    function send(uint32 _destinationChainId, bytes32 _destinationAddress, bytes calldata _data)
        external
        isSendingEnabled
        returns (bytes32)
    {
        if (_destinationChainId == block.chainid) revert CannotSendToSameChain();
        (bytes memory message, bytes32 messageId) =
            _getMessageAndId(_destinationChainId, _destinationAddress, _data);
        messages[nonce] = messageId;
        emit SentMessage(nonce++, messageId, message);
        return messageId;
    }

    /// @notice Sends a message to a destination chain.
    /// @param _destinationChainId The chain id that specifies the destination chain.
    /// @param _destinationAddress The contract address that will be called on the destination
    ///        chain.
    /// @param _data The data passed to the contract on the other chain
    /// @return messageId A unique identifier for a message.
    function send(uint32 _destinationChainId, address _destinationAddress, bytes calldata _data)
        external
        isSendingEnabled
        returns (bytes32)
    {
        if (_destinationChainId == block.chainid) revert CannotSendToSameChain();
        (bytes memory message, bytes32 messageId) =
            _getMessageAndId(_destinationChainId, Bytes32.fromAddress(_destinationAddress), _data);
        messages[nonce] = messageId;
        emit SentMessage(nonce++, messageId, message);
        return messageId;
    }

    /// @notice Gets the message and message root from the user-provided arguments to `send`
    /// @param _destinationChainId The chain id that specifies the destination chain.
    /// @param _destinationAddress The contract address that will be called on the destination
    ///        chain.
    /// @param _data The calldata used when calling the contract on the destination chain.
    /// @return message The message encoded as bytes, used in SentMessage event.
    /// @return messageId The hash of message, used as a unique identifier for a message.
    function _getMessageAndId(
        uint32 _destinationChainId,
        bytes32 _destinationAddress,
        bytes calldata _data
    ) internal view returns (bytes memory message, bytes32 messageId) {
        message = Message.encode(
            version,
            nonce,
            uint32(block.chainid),
            msg.sender,
            _destinationChainId,
            _destinationAddress,
            _data
        );
        messageId = keccak256(message);
    }

    // These are all functions for EthCall Attestation

    function getMessageId(uint64 _nonce) external view returns (bytes32) {
        return messages[_nonce];
    }

    function getMessageIdBulk(uint64[] calldata _nonces) public view returns (bytes32[] memory) {
        bytes32[] memory messageIds = new bytes32[](_nonces.length);
        for (uint256 i = 0; i < _nonces.length; i++) {
            messageIds[i] = messages[_nonces[i]];
        }
        return messageIds;
    }

    function getMessageIdBulkHash(uint64[] calldata _nonces) external view returns (bytes32) {
        return keccak256(abi.encode(getMessageIdBulk(_nonces)));
    }

    function getMessageIdRoot(uint64[] memory _nonces) external view returns (bytes32) {
        uint256 n = _nonces.length;
        require((n & (n - 1)) == 0, "nonces must be perfect power of 2");

        bytes32[] memory messageIds = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            messageIds[i] = messages[_nonces[i]];
        }

        while (n > 1) {
            for (uint256 i = 0; i < n / 2; i++) {
                messageIds[i] =
                    keccak256(abi.encodePacked(messageIds[2 * i], messageIds[2 * i + 1]));
            }
            if (n % 2 == 1) {
                messageIds[n / 2] = messageIds[n - 1];
                n = n / 2 + 1;
            } else {
                n = n / 2;
            }
        }

        return bytes32(messageIds[0]);
    }

    function getProofDataForExecution(uint64[] memory _nonces, uint64 _nonce)
        external
        view
        returns (bytes memory)
    {
        // Find the index of the nonce
        uint256 index;
        for (uint256 i = 0; i < _nonces.length; i++) {
            if (_nonces[i] == _nonce) {
                index = i;
                break;
            }
        }

        // Generate the leaf nodes
        bytes32[] memory nodes = new bytes32[](_nonces.length);
        for (uint256 i = 0; i < _nonces.length; i++) {
            nodes[i] = messages[_nonces[i]];
        }

        bytes32[] memory proof = MerkleProof.getProof(nodes, index);
        return abi.encode(this.getMessageIdRoot.selector, _nonces, index, proof);
    }
}
