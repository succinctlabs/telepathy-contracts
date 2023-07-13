// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {MessageStatus} from "src/amb-v2/interfaces/ITelepathy.sol";
import {VerifierType} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";

contract TelepathyStorageV2 {
    /*//////////////////////////////////////////////////////////////
                           BROADCASTER STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Whether sending is enabled or not.
    bool public sendingEnabled;

    /// @notice Mapping between a nonce and a message root.
    mapping(uint64 => bytes32) public messages;

    /// @notice Keeps track of the next nonce to be used.
    uint64 public nonce;

    /*//////////////////////////////////////////////////////////////
                           RECEIVER STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice All sourceChainIds.
    /// @dev DEPRECATED: This is no longer in use since the move over to external IMessageVerifiers.
    uint32[] public sourceChainIds;

    /// @notice Mapping between source chainId and the corresponding light client.
    /// @dev DEPRECATED: This is no longer in use since the move over to external IMessageVerifiers.
    mapping(uint32 => ILightClient) public lightClients;

    /// @notice Mapping between source chainId and the address of the TelepathyRouterV2 on that chain.
    /// @dev DEPRECATED: This is no longer in use since the move over to external IMessageVerifiers.
    mapping(uint32 => address) public broadcasters;

    /// @notice Mapping between a source chainId and whether it's frozen.
    /// @dev DEPRECATED: This is no longer in use, a global bool 'executingEnabled' is now used.
    mapping(uint32 => bool) public frozen;

    /// @notice Mapping between a message root and its status.
    mapping(bytes32 => MessageStatus) public messageStatus;

    /*//////////////////////////////////////////////////////////////
                           SHARED STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns current contract version.
    uint8 public version;

    /*//////////////////////////////////////////////////////////////
                        RECEIVER STORAGE V2
    //////////////////////////////////////////////////////////////*/

    /// @notice Storage root cache.
    /// @dev DEPRECATED: This is no longer in use since the move over to external IMessageVerifiers.
    mapping(bytes32 => bytes32) public storageRootCache;

    /// @notice Default verifier contracts for each type.
    mapping(VerifierType => address) public defaultVerifiers;

    /// @notice Whether executing messages is enabled or not.
    bool public executingEnabled;

    /// @notice Whitelisted relayers that can execute messages with the ZK verifiers.
    mapping(address => bool) public zkRelayers;

    /// @dev This empty reserved space is put in place to allow future versions to add new variables
    /// without shifting down storage in the inheritance chain.
    /// See: https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#storage-gaps
    uint256[37] private __gap;
}
