// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {VerifierType, IMessageVerifier} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";
import {SourceAMBV2} from "src/amb-v2/SourceAMB.sol";
import {Message} from "src/libraries/Message.sol";

/// @notice Struct for eth_call request information wrapped with the attested result.
/// @param chainId The chain ID of the chain where the eth_call will be made.
/// @param blockNumber The block number of the chain where the eth_call is made.
///        If blockNumber is 0, then the eth_call is made at the latest avaliable
///        block.
/// @param fromAddress The address that is used as the 'from' eth_call argument
///        (influencing msg.sender & tx.origin). If set to address(0) then the
///        call is made from address(0).
/// @param toAddress The address that is used as the 'to' eth_call argument.
/// @param toCalldata The calldata that is used as the 'data' eth_call argument.
/// @param result The result from executing the eth_call.
struct EthCallResponse {
    uint32 chainId;
    uint64 blockNumber;
    address fromAddress;
    address toAddress;
    bytes toCalldata;
    bytes result;
}

interface IEthCallGateway {
    /// @notice The response currently being processed by the gateway.
    function currentResponse() external view returns (EthCallResponse memory);
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
    error InvalidChainId(uint32 chainId);
    error TelepathyRouterNotFound(uint32 sourceChainId);
    error TelepathyRouterIncorrect(address telepathyRouter);
    error InvalidResult();
    error InvalidToCalldata(bytes toCalldata);
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
    /// @dev The first argument will be the same as the response.result (in the expected case),
    ///      so it is better to just ignore it.
    /// @param _message The message to verify.
    function verify(bytes calldata, bytes calldata _message)
        external
        view
        override
        returns (bool)
    {
        EthCallResponse memory response = IEthCallGateway(ethCallGateway).currentResponse();
        if (response.result.length == 0) {
            revert InvalidResult();
        }

        // Check that the attestation is from the same chain as the message.
        if (response.chainId != _message.sourceChainId()) {
            revert InvalidChainId(response.chainId);
        }

        // Check that the attestation is from the same contract as the telepathyRouter.
        address telepathyRouter = telepathyRouters[response.chainId];
        if (telepathyRouter == address(0)) {
            revert TelepathyRouterNotFound(response.chainId);
        }
        if (response.toAddress != telepathyRouter) {
            revert TelepathyRouterIncorrect(response.toAddress);
        }

        // Check that the attestation toCalldata has the correct function selector and nonce.
        bytes memory expectedToCalldata =
            abi.encodeWithSelector(SourceAMBV2.getMessageId.selector, _message.nonce());
        if (keccak256(abi.encode(response.toCalldata)) != keccak256(abi.encode(expectedToCalldata)))
        {
            revert InvalidToCalldata(response.toCalldata);
        }

        // Check that the claimed messageId matches the attested ethcall result for
        // "getMessageId(uint64)".
        bytes32 attestedMsgId = abi.decode(response.result, (bytes32));
        if (attestedMsgId != _message.getId()) {
            revert InvalidMessageId(attestedMsgId);
        }

        return true;
    }
}
