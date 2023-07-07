// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {TelepathyStorageV2} from "src/amb-v2/TelepathyStorage.sol";
import {VerifierType} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";
import {AccessControlUpgradeable} from
    "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

contract TelepathyAccessV2 is TelepathyStorageV2, AccessControlUpgradeable {
    /// @notice Emitted when the sendingEnabled flag is changed.
    event SendingEnabledChanged(bool enabled);

    /// @notice Emitted when the executingEnabled flag is changed.
    event ExecutingEnabledChanged(bool enabled);

    /// @notice A random constant used to identify addresses with the permission of a 'guardian'.
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice A random constant used to identify addresses with the permission of a 'timelock'.
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    error OnlyAdmin(address sender);
    error OnlyTimelock(address sender);
    error OnlyGuardian(address sender);

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdmin(msg.sender);
        }
        _;
    }

    modifier onlyTimelock() {
        if (!hasRole(TIMELOCK_ROLE, msg.sender)) {
            revert OnlyTimelock(msg.sender);
        }
        _;
    }

    modifier onlyGuardian() {
        if (!hasRole(GUARDIAN_ROLE, msg.sender)) {
            revert OnlyGuardian(msg.sender);
        }
        _;
    }

    /// @notice Allows the owner to control whether sending is enabled or not.
    /// @param enabled Whether sending should be enabled or not.
    function setSendingEnabled(bool enabled) external onlyGuardian {
        sendingEnabled = enabled;
        emit SendingEnabledChanged(enabled);
    }

    /// @notice Allows the owner to control whether executing is enabled or not.
    /// @param enabled Whether executing should be enabled or not.
    function setExecutingEnabled(bool enabled) external onlyGuardian {
        executingEnabled = enabled;
        emit ExecutingEnabledChanged(enabled);
    }

    /// @notice Sets the default IMessageVerifier contract for a given VerifierType.
    /// @param _verifierType The VerifierType to set the default verifier for.
    /// @param _verifier The address of the default verifier.
    function setDefaultVerifier(VerifierType _verifierType, address _verifier)
        external
        onlyTimelock
    {
        defaultVerifiers[_verifierType] = _verifier;
    }

    /// @notice Sets the current version of the contract.
    /// @param _version The new version.
    function setVersion(uint8 _version) external onlyTimelock {
        version = _version;
    }
}
