pragma solidity ^0.8.16;

import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from
    "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {EigenLayerBeaconOracle} from "external/integrations/eigenlayer/EigenLayerBeaconOracle.sol";

/// @title EigenLayer Beacon Oracle Proxy
/// @author Succinct Labs
/// @notice Store a mapping of block numbers to beacon state roots.
contract EigenLayerBeaconOracleProxy is
    EigenLayerBeaconOracle,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    /// @notice A random constant used to identify addresses with the permission of a 'timelock'.
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    /// @notice A random constant used to identify addresses with the permission of a 'guardian'.
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice Invalid light client address error.
    error InvalidLightClientAddress();

    modifier onlyTimelock() {
        require(hasRole(TIMELOCK_ROLE, msg.sender), "EigenLayerBeaconOracleProxy: not timelock");
        _;
    }

    modifier onlyGuardian() {
        require(hasRole(GUARDIAN_ROLE, msg.sender), "EigenLayerBeaconOracleProxy: not guardian");
        _;
    }

    /// @notice Prevents the implementation contract from being initialized outside of the 
    /// upgradeable proxy.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract and the parent contracts once.
    function initialize(address _lightClient, address _timelock, address _guardian, address _operator)
        external
        initializer
    {
        __AccessControl_init();
        _grantRole(TIMELOCK_ROLE, _timelock);
        _grantRole(DEFAULT_ADMIN_ROLE, _timelock);
        _grantRole(GUARDIAN_ROLE, _guardian);
        __UUPSUpgradeable_init();

        if (_lightClient == address(0)) {
            revert InvalidLightClientAddress();
        }

        whitelistedOracleUpdaters[_operator] = true;
        lightclient = ILightClient(_lightClient);
    }

    /// @notice Updates the whitelist of addresses that can update the beacon state root.
    function updateWhitelist(address _oracleUpdater, bool _isWhitelisted) external onlyGuardian {
        whitelistedOracleUpdaters[_oracleUpdater] = _isWhitelisted;
    }

    /// @notice Update the light client contract.
    function updateLightClient(address _lightClient) external onlyTimelock {
        lightclient = ILightClient(_lightClient);
    }

    /// @notice Authorizes an upgrade for the implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyTimelock {}
}
