// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {TelepathyStorage} from "src/amb-v2/TelepathyStorage.sol";
import {VerifierType} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";
import {AccessControlUpgradeable} from
    "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

contract TelepathyAccess is TelepathyStorage, AccessControlUpgradeable {
    /// @notice Emitted when the sendingEnabled flag is changed.
    event SendingEnabledChanged(bool enabled);

    /// @notice Emitted when the executingEnabled flag is changed.
    event ExecutingEnabledChanged(bool enabled);

    /// @notice A random constant used to identify addresses with the permission of a 'guardian'.
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice A random constant used to identify addresses with the permission of a 'timelock'.
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "TelepathyRouter: only admin can call this function"
        );
        _;
    }

    modifier onlyTimelock() {
        require(
            hasRole(TIMELOCK_ROLE, msg.sender),
            "TelepathyRouter: only timelock can call this function"
        );
        _;
    }

    modifier onlyGuardian() {
        require(
            hasRole(GUARDIAN_ROLE, msg.sender),
            "TelepathyRouter: only guardian can call this function"
        );
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
}
