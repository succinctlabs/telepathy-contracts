// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";

/// @title BeaconVerifierBase
/// @author Succinct Labs
/// @notice Base contract for verifiers to use when verifying against the Beacon LightClient.
contract BeaconVerifierBase {
    /// @notice Source ChainId => LightClient address.
    mapping(uint32 => address) public lightClients;
    /// @notice Source ChainId => TelepathyRouterV2 address.
    mapping(uint32 => address) public telepathyRouters;

    error InvalidSourceChainLength(uint256 length);
    error LightClientNotFound(uint32 sourceChainId);
    error TelepathyRouterNotFound(uint32 sourceChainId);

    constructor(
        uint32[] memory _sourceChainIds,
        address[] memory _lightClients,
        address[] memory _telepathyRouters
    ) {
        if (_sourceChainIds.length != _lightClients.length) {
            revert InvalidSourceChainLength(_sourceChainIds.length);
        }
        if (_sourceChainIds.length != _telepathyRouters.length) {
            revert InvalidSourceChainLength(_sourceChainIds.length);
        }
        for (uint32 i = 0; i < _sourceChainIds.length; i++) {
            lightClients[_sourceChainIds[i]] = _lightClients[i];
            telepathyRouters[_sourceChainIds[i]] = _telepathyRouters[i];
        }
    }
}
