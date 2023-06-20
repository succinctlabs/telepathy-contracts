// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {VerifierType, IMessageVerifier} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";
import {SourceAMBV2} from "src/amb-v2/SourceAMB.sol";
import {Message} from "src/libraries/Message.sol";
import {MerkleProof} from "src/libraries/MerkleProof.sol";

interface IEthCallGateway {
    function getAttestedResult(uint32 chainId, address toAddress, bytes memory toCalldata)
        external
        returns (bytes memory);
}

/// @title TelepathyAttestationVerifier
/// @author Succinct Labs
/// @notice Verifies messages using Telepathy EthCall attestations.
contract TelepathyAttestationVerifier is IMessageVerifier {
    using Message for bytes;

    /// @notice The address of the EthCallGateway contract.
    address public immutable ethCallGateway;
    /// @notice Source ChainId => TelepathyRouterV2 address.
    mapping(uint32 => address) public telepathyRouters;

    error InvalidSourceChainLength(uint256 length);
    error TelepathyRouterNotFound(uint32 sourceChainId);
    error InvalidMessageId(bytes32 messageId);
    error InvalidFuncSelector(bytes4 selector);

    constructor(
        address _ethCallGateway,
        uint32[] memory _sourceChainIds,
        address[] memory _telepathyRouters
    ) {
        ethCallGateway = _ethCallGateway;
        if (_sourceChainIds.length != _telepathyRouters.length) {
            revert InvalidSourceChainLength(_sourceChainIds.length);
        }
        for (uint32 i = 0; i < _sourceChainIds.length; i++) {
            telepathyRouters[_sourceChainIds[i]] = _telepathyRouters[i];
        }
    }

    function verifierType() external pure override returns (VerifierType) {
        return VerifierType.ATTESTATION_ETHCALL;
    }

    /// @notice Verifies messages using Telepathy EthCall attestations.
    /// @param _proofData The proof of the message, which is either (1) empty in the
    ///        case of a single message, or (2) contains:
    ///             bytes4 ambSelector
    ///             uint64[] nonces
    ///             uint256 index
    ///             bytes32[] merkleProof
    ///        in the case of bulk attestations.
    /// @param _message The message to verify.
    function verify(bytes calldata _proofData, bytes calldata _message)
        external
        override
        returns (bool)
    {
        bytes32 msgId = _message.getId();
        uint32 sourceChainId = _message.sourceChainId();
        address telepathyRouter = telepathyRouters[sourceChainId];

        if (telepathyRouter == address(0)) {
            revert TelepathyRouterNotFound(sourceChainId);
        }

        if (_proofData.length == 0) {
            // Verifying a single attestation
            bytes memory toCalldata =
                abi.encodeWithSelector(SourceAMBV2.getMessageId.selector, _message.nonce());
            bytes memory attestedResult = IEthCallGateway(ethCallGateway).getAttestedResult(
                sourceChainId, telepathyRouter, toCalldata
            );

            // Check that the claimed messageId matches the attested ethcall result for getMessageId()
            bytes32 attestedId = abi.decode(attestedResult, (bytes32));
            if (msgId != attestedId) {
                revert InvalidMessageId(msgId);
            }
        } else {
            // Verifying bulk attestations
            (
                bytes4 ambSelector,
                uint64[] memory nonces,
                uint256 index,
                bytes32[] memory merkleProof
            ) = abi.decode(_proofData, (bytes4, uint64[], uint256, bytes32[]));

            bytes memory toCalldata;
            if (ambSelector == SourceAMBV2.getMessageIdBulk.selector) {
                toCalldata = abi.encodeWithSelector(SourceAMBV2.getMessageIdBulk.selector, nonces);
                bytes memory attestedResult = IEthCallGateway(ethCallGateway).getAttestedResult(
                    sourceChainId, telepathyRouter, toCalldata
                );
                bytes32[] memory ids = abi.decode(attestedResult, (bytes32[]));
                if (ids[index] != msgId) {
                    revert InvalidMessageId(msgId);
                }
            } else if (ambSelector == SourceAMBV2.getMessageIdRoot.selector) {
                toCalldata = abi.encodeWithSelector(SourceAMBV2.getMessageIdRoot.selector, nonces);
                bytes memory attestedResult = IEthCallGateway(ethCallGateway).getAttestedResult(
                    sourceChainId, telepathyRouter, toCalldata
                );
                bytes32 root = abi.decode(attestedResult, (bytes32));
                bool verified = MerkleProof.verifyProof(root, msgId, merkleProof, index);
                if (!verified) {
                    revert InvalidMessageId(msgId);
                }
            } else {
                revert InvalidFuncSelector(ambSelector);
            }
        }

        return true;
    }
}
