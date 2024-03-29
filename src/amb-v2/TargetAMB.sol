// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {ReentrancyGuardUpgradeable} from
    "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import {Message} from "src/libraries/Message.sol";
import {TelepathyStorageV2} from "src/amb-v2/TelepathyStorage.sol";
import {
    BROADCAST_ALL_CHAINS,
    ITelepathyHandlerV2,
    ITelepathyReceiverV2,
    MessageStatus
} from "src/amb-v2/interfaces/ITelepathy.sol";
import {VerifierType, IMessageVerifier} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";

/// @title Target Arbitrary Message Bridge
/// @author Succinct Labs
/// @notice Executes messages sent from the source chain on the destination chain.
contract TargetAMBV2 is TelepathyStorageV2, ReentrancyGuardUpgradeable, ITelepathyReceiverV2 {
    using Message for bytes;

    error ExecutingDisabled();
    error MessageAlreadyExecuted(bytes32 messageId);
    error MessageNotForChain(bytes32 messageId, uint32 destinationChainId, uint32 currentChainId);
    error MessageWrongVersion(bytes32 messageId, uint8 messageVersion, uint8 currentVersion);
    error VerifierNotFound(uint256 verifierType);
    error NotZkRelayer(address sender);
    error VerificationFailed();
    error CallFailed();
    error InvalidSelector();

    modifier isExecutingEnabled() {
        if (!executingEnabled) {
            revert ExecutingDisabled();
        }
        _;
    }

    /// @notice Execute a message generically
    /// @param _proofData The proof of the message, which gets used for verification.
    /// @param _message The message to be executed.
    function execute(bytes calldata _proofData, bytes calldata _message)
        external
        isExecutingEnabled
        nonReentrant
    {
        bytes32 messageId = _message.getId();
        _checkMessagePreconditions(messageId, _message.version(), _message.destinationChainId());

        VerifierType _verifierType = getVerifierType(_message);
        _verifyMessage(_verifierType, _proofData, _message);

        _executeMessage(_message, messageId);
    }

    /// @notice Retrieves the verifier for a message.
    /// @dev If the destination address specifies a custom verifier, that verifierType is used.
    ///      Otherwise, the default verifierType for the source chain is used.
    /// @param _message The message to get the verifier for.
    /// @return verifierType The type of verifierType to use.
    function getVerifierType(bytes memory _message) public view returns (VerifierType) {
        address verifier = _message.destinationAddress();
        try IMessageVerifier(verifier).verifierType() returns (VerifierType _verifierType) {
            // If the destination address doesn't specify a VerifierType, we use our defaults
            if (_verifierType != VerifierType.NULL) {
                return _verifierType;
            }
            // solhint-disable-next-line no-empty-blocks
        } catch {}

        // Return our default choice of verifier
        uint32 sourceChain = _message.sourceChainId();

        // For Mainnet, Goerli, and Gnosis as source, return ZK verification
        if (sourceChain == 1 || sourceChain == 5 || sourceChain == 100) {
            return VerifierType.ZK_EVENT;
        }
        // Otherwise use the Attestation verification
        return VerifierType.ATTESTATION_STATE_QUERY;
    }

    /// @notice Checks message conditions before execution.
    /// @param _messageId The message unique identifier.
    /// @param _version The message version.
    /// @param _destinationChainId The destination chainId.
    function _checkMessagePreconditions(
        bytes32 _messageId,
        uint8 _version,
        uint32 _destinationChainId
    ) internal view {
        if (messageStatus[_messageId] != MessageStatus.NOT_EXECUTED) {
            revert MessageAlreadyExecuted(_messageId);
        } else if (
            _destinationChainId != BROADCAST_ALL_CHAINS
                && _destinationChainId != uint32(block.chainid)
        ) {
            revert MessageNotForChain(_messageId, _destinationChainId, uint32(block.chainid));
        } else if (_version != version) {
            revert MessageWrongVersion(_messageId, _version, version);
        }
    }

    /// @notice Verifies a message.
    /// @param verifierType The type of verifier to use.
    /// @param _proofData The packed proof data that the proves the message is valid.
    /// @param _message The message contents.
    function _verifyMessage(
        VerifierType verifierType,
        bytes memory _proofData,
        bytes memory _message
    ) internal {
        // If the verifier is a ZK verifier, check that the sender is an allowed relayer
        if (verifierType == VerifierType.ZK_EVENT || verifierType == VerifierType.ZK_STORAGE) {
            if (!zkRelayers[msg.sender]) {
                revert NotZkRelayer(msg.sender);
            }
        }

        address verifier;
        if (verifierType == VerifierType.CUSTOM) {
            verifier = _message.destinationAddress();
        } else {
            verifier = defaultVerifiers[verifierType];
        }
        if (verifier == address(0)) {
            revert VerifierNotFound(uint256(verifierType));
        }

        try IMessageVerifier(verifier).verify(_proofData, _message) returns (bool isValid) {
            if (!isValid) {
                revert VerificationFailed();
            }
        } catch {
            revert VerificationFailed();
        }
    }

    /// @notice Executes a message and updates storage with status and emits an event.
    /// @dev Assumes that the message has not been already been executed, and that
    ///      message, and messageId have already been validated.
    /// @param _message The message to be executed.
    /// @param _messageId The unique message identifier.
    function _executeMessage(bytes memory _message, bytes32 _messageId) internal {
        messageStatus[_messageId] = MessageStatus.EXECUTION_SUCCEEDED;

        bool success;
        bytes memory data;
        {
            bytes memory receiveCall = abi.encodeWithSelector(
                ITelepathyHandlerV2.handleTelepathy.selector,
                _message.sourceChainId(),
                _message.sourceAddress(),
                _message.data()
            );
            address destination = _message.destinationAddress();
            (success, data) = destination.call(receiveCall);
        }

        // Unfortunately, there are some edge cases where a call may have a successful status but
        // not have actually called the handler. Thus, we enforce that the handler must return
        // a magic constant that we can check here. To avoid stack underflow / decoding errors, we
        // only decode the returned bytes if one EVM word was returned by the call.
        bool implementsHandler = false;
        if (data.length == 32) {
            (bytes4 magic) = abi.decode(data, (bytes4));
            implementsHandler = magic == ITelepathyHandlerV2.handleTelepathy.selector;
        }

        if (!success) {
            revert CallFailed();
        } else if (!implementsHandler) {
            revert InvalidSelector();
        }

        emit ExecutedMessage(
            _message.sourceChainId(), _message.nonce(), _messageId, _message, success
        );
    }
}
