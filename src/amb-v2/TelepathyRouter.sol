// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {TelepathyStorageV2} from "src/amb-v2/TelepathyStorage.sol";
import {
    ITelepathyReceiverV2,
    MessageStatus,
    ITelepathyHandlerV2,
    ITelepathyRouterV2
} from "src/amb-v2/interfaces/ITelepathy.sol";
import {TargetAMBV2} from "src/amb-v2/TargetAMB.sol";
import {SourceAMBV2} from "src/amb-v2/SourceAMB.sol";
import {TelepathyAccessV2} from "src/amb-v2/TelepathyAccess.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title Telepathy Router
/// @author Succinct Labs
/// @notice Send and receive arbitrary messages from other chains.
contract TelepathyRouterV2 is SourceAMBV2, TargetAMBV2, TelepathyAccessV2, UUPSUpgradeable {
    /// @notice Returns current contract version.
    uint8 public constant VERSION = 1;

    /// @notice Prevents the implementation contract from being initialized outside of the upgradeable proxy.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract and the parent contracts once.
    /// @dev As of the switch to use external IMessageVerifiers, lightClients and telepathyRouters
    ///      are no longer stored and should not be passed in to this function.
    function initialize(
        uint32[] memory _sourceChainIds,
        address[] memory,
        address[] memory,
        address _timelock,
        address _guardian,
        bool _sendingEnabled
    ) external initializer {
        __ReentrancyGuard_init();
        __AccessControl_init();
        _grantRole(GUARDIAN_ROLE, _guardian);
        _grantRole(TIMELOCK_ROLE, _timelock);
        _grantRole(DEFAULT_ADMIN_ROLE, _timelock);
        __UUPSUpgradeable_init();

        require(
            _sourceChainIds.length == 0,
            "TelepathyRouterV2 no longer stores lightClients and telepathyRouters"
        );

        sendingEnabled = _sendingEnabled;
        executingEnabled = true; // TODO: set from a parameter
        version = VERSION;
    }

    /// @notice Authorizes an upgrade for the implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyTimelock {}
}
