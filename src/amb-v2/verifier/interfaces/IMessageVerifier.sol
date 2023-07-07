// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

enum VerifierType {
    NULL,
    CUSTOM,
    ZK_EVENT,
    ZK_STORAGE,
    ATTESTATION_STATE_QUERY
}

/// @title IMessageVerifier
/// @author Succinct Labs
/// @notice Interface for a message verifier.
interface IMessageVerifier {
    /// @notice Returns the type of the verifier.
    /// @dev This signals what type of proofData to include for the message.
    function verifierType() external view returns (VerifierType);

    /// @notice Verifies a message.
    /// @param proofData The packed proof data that the proves the message is valid.
    /// @param message The message contents.
    /// @return isValid Whether the message is valid.
    function verify(bytes calldata proofData, bytes calldata message) external returns (bool);
}
