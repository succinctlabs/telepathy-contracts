pragma solidity ^0.8.16;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";

contract EigenLayerBeaconOracleStorage {
    /// @notice The light client contract.
    ILightClient public lightclient;

    /// @notice The whitelist for the oracle updaters.
    mapping(address => bool) public whitelistedOracleUpdaters;

    /// @notice The block number to state root mapping.
    mapping(uint256 => bytes32) public timestampToBlockRoot;

    /// @dev This empty reserved space is put in place to allow future versions to add new variables
    /// without shifting down storage in the inheritance chain.
    /// See: https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#storage-gaps
    uint256[50] private __gap;
}
