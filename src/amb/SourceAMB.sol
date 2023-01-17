pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "src/amb/interfaces/IAMB.sol";

/// @title Source Arbitrary Message Bridge
/// @author Succinct Labs
/// @notice This contract is the entrypoint for making a cross-chain call.
contract SourceAMB is IBroadcaster {
    /// @notice Mapping between a nonce and a message root.
    mapping(uint256 => bytes32) public messages;

    /// @notice Keeps track of the next nonce to be used.
    uint256 public nonce = 1;

    /// @notice Sends a message to a target chain.
    /// @param recipient The contract address that will be called on the target chain.
    /// @param recipientChainId The chain id that specifies the target chain.
    /// @param gasLimit The maximum amount of gas the call on the target chain is allowed to take.
    /// @param data The calldata used when calling the contract on the target chain.
    /// @return bytes32 A unique identifier for a message.
    function send(address recipient, uint16 recipientChainId, uint256 gasLimit, bytes calldata data)
        external
        returns (bytes32)
    {
        bytes memory message =
            abi.encode(nonce, msg.sender, recipient, recipientChainId, gasLimit, data);
        bytes32 messageRoot = keccak256(message);
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    /// @notice Sends a message to a target chain using an event proof instead of a storage proof.
    /// @param recipient The contract address that will be called on the target chain.
    /// @param recipientChainId The chain id that specifies the target chain.
    /// @param gasLimit The maximum amount of gas the call on the target chain is allowed to take.
    /// @param data The calldata used when calling the contract on the target chain.
    /// @return bytes32 A unique identifier for a message.
    function sendViaLog(
        address recipient,
        uint16 recipientChainId,
        uint256 gasLimit,
        bytes calldata data
    ) external returns (bytes32) {
        bytes memory message =
            abi.encode(nonce, msg.sender, recipient, recipientChainId, gasLimit, data);
        bytes32 messageRoot = keccak256(message);
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }
}
