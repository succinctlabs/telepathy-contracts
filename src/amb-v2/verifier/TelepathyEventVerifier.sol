// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {VerifierType, IMessageVerifier} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";
import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {EventProof} from "src/libraries/StateProofHelper.sol";
import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {Message} from "src/libraries/Message.sol";
import {BeaconVerifierBase} from "src/amb-v2/verifier/BeaconVerifierBase.sol";

/// @title TelepathyEventVerifier
/// @author Succinct Labs
/// @notice Verifies that an event for the message was emitted by the source chain's
///         TelepathyRouter.
contract TelepathyEventVerifier is IMessageVerifier, BeaconVerifierBase {
    using Message for bytes;

    /// @notice The TelepathyRouter SentMessage event signature used in `executeMessageFromLog`.
    bytes32 internal constant SENT_MESSAGE_EVENT_SIG =
        keccak256("SentMessage(uint64,bytes32,bytes)");

    /// @notice The topic index of the message root in the SourceAMB SentMessage event.
    /// @dev Because topic[0] is the hash of the event signature (`SENT_MESSAGE_EVENT_SIG` above),
    ///      the topic index of messageId is 2.
    uint256 internal constant MESSAGE_ID_TOPIC_IDX = 2;

    error HeaderNotFound(address lightClient, uint64 slot);
    error InvalidReceiptsRootProof();
    error InvalidEventProof();

    constructor(
        uint32[] memory _sourceChainIds,
        address[] memory _lightClients,
        address[] memory _telepathyRouters
    ) BeaconVerifierBase(_sourceChainIds, _lightClients, _telepathyRouters) {}

    function verifierType() external pure override returns (VerifierType) {
        return VerifierType.ZK_EVENT;
    }

    /// @notice Verifies a message using an event (receipt) proof.
    /// @param _proofData The proof of the message, which contains:
    ///     bytes calldata srcSlotTxSlotPack
    ///     bytes calldata message
    ///     bytes32[] calldata receiptsRootProof
    ///     bytes32 receiptsRoot
    ///     bytes[] calldata receiptProof
    ///     bytes memory txIndexRLPEncoded
    ///     uint256 logIndex
    /// @param _message The message to verify.
    function verify(bytes calldata _proofData, bytes calldata _message)
        external
        view
        override
        returns (bool)
    {
        (
            bytes memory srcSlotTxSlotPack,
            bytes32[] memory receiptsRootProof,
            bytes32 receiptsRoot,
            bytes[] memory receiptProof,
            bytes memory txIndexRLPEncoded,
            uint256 logIndex
        ) = abi.decode(_proofData, (bytes, bytes32[], bytes32, bytes[], bytes, uint256));
        (uint64 srcSlot, uint64 txSlot) = abi.decode(srcSlotTxSlotPack, (uint64, uint64));

        uint32 sourceChainId = _message.sourceChainId();
        address lightClient = lightClients[sourceChainId];
        if (lightClient == address(0)) {
            revert LightClientNotFound(sourceChainId);
        }

        {
            bytes32 headerRoot = ILightClient(lightClient).headers(srcSlot);
            if (headerRoot == bytes32(0)) {
                revert HeaderNotFound(lightClient, srcSlot);
            }

            bool isValid = SSZ.verifyReceiptsRoot(
                receiptsRoot, receiptsRootProof, headerRoot, srcSlot, txSlot, sourceChainId
            );
            if (!isValid) {
                revert InvalidReceiptsRootProof();
            }
        }

        {
            address telepathyRouter = telepathyRouters[sourceChainId];
            if (telepathyRouter == address(0)) {
                revert TelepathyRouterNotFound(sourceChainId);
            }
            bytes32 receiptMessageRoot = bytes32(
                EventProof.getEventTopic(
                    receiptProof,
                    receiptsRoot,
                    txIndexRLPEncoded,
                    logIndex,
                    telepathyRouter,
                    SENT_MESSAGE_EVENT_SIG,
                    MESSAGE_ID_TOPIC_IDX
                )
            );
            if (receiptMessageRoot != _message.getId()) {
                revert InvalidEventProof();
            }
        }

        return true;
    }
}
