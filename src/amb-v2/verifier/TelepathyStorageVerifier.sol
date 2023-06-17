// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {VerifierType, IMessageVerifier} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";
import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {StorageProof} from "src/libraries/StateProofHelper.sol";
import {Message} from "src/libraries/Message.sol";
import {BeaconVerifierBase} from "src/amb-v2/verifier/BeaconVerifierBase.sol";

/// @title TelepathyStorageVerifier
/// @author Succinct Labs
/// @notice Verifies messages using a storage proof of inclusion in the source chain's
///         TelepathyRouter.
contract TelepathyStorageVerifier is IMessageVerifier, BeaconVerifierBase {
    using Message for bytes;

    /// @notice The index of the `messages` mapping in TelepathyStorage.sol.
    /// @dev We need this when calling `executeMessage` via storage proofs, as it is used in
    /// getting the slot key.
    uint256 internal constant MESSAGES_MAPPING_STORAGE_INDEX = 1;

    /// @notice A cache to avoid redundant storageProof calculation.
    mapping(bytes32 => bytes32) public storageRootCache;

    error ExecutionStateRootNotSet(address lightClient, uint64 slot);
    error InvalidStorageProof();

    constructor(
        uint32[] memory _sourceChainIds,
        address[] memory _lightClients,
        address[] memory _telepathyRouters
    ) BeaconVerifierBase(_sourceChainIds, _lightClients, _telepathyRouters) {}

    function verifierType() external pure override returns (VerifierType) {
        return VerifierType.ZK_STORAGE;
    }

    /// @notice Verifies a message using a storage proof.
    /// @param _proofData The proof of the message, which contains:
    ///     uint64 slot
    ///     bytes calldata message
    ///     bytes[] calldata accountProof
    ///     bytes[] calldata storageProof
    /// @param _message The message to verify.
    function verify(bytes calldata _proofData, bytes calldata _message)
        external
        override
        returns (bool)
    {
        (uint64 slot, bytes[] memory accountProof, bytes[] memory storageProof) =
            abi.decode(_proofData, (uint64, bytes[], bytes[]));

        uint32 sourceChainId = _message.sourceChainId();
        address lightClient = lightClients[sourceChainId];
        if (lightClient == address(0)) {
            revert LightClientNotFound(sourceChainId);
        }

        address telepathyRouter = telepathyRouters[sourceChainId];
        if (telepathyRouter == address(0)) {
            revert TelepathyRouterNotFound(sourceChainId);
        }

        bytes32 storageRoot;
        bytes32 cacheKey = keccak256(abi.encodePacked(sourceChainId, slot, telepathyRouter));

        // If the cache is empty for the cacheKey, then we get the
        // storageRoot using the provided accountProof.
        if (storageRootCache[cacheKey] == 0) {
            bytes32 executionStateRoot = ILightClient(lightClient).executionStateRoots(slot);
            if (executionStateRoot == 0) {
                revert ExecutionStateRootNotSet(lightClient, slot);
            }
            storageRoot =
                StorageProof.getStorageRoot(accountProof, telepathyRouter, executionStateRoot);
            storageRootCache[cacheKey] = storageRoot;
        } else {
            storageRoot = storageRootCache[cacheKey];
        }

        bytes32 slotKey = keccak256(
            abi.encode(keccak256(abi.encode(_message.nonce(), MESSAGES_MAPPING_STORAGE_INDEX)))
        );
        uint256 slotValue = StorageProof.getStorageValue(slotKey, storageRoot, storageProof);

        if (bytes32(slotValue) != _message.getId()) {
            revert InvalidStorageProof();
        }

        return true;
    }
}
