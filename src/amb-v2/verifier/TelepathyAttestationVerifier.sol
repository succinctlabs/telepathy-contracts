// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {VerifierType, IMessageVerifier} from "src/amb-v2/verifier/interfaces/IMessageVerifier.sol";
import {SourceAMBV2} from "src/amb-v2/SourceAMB.sol";
import {Message} from "src/libraries/Message.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

/// @notice Struct for StateQuery request information wrapped with the attested result.
/// @dev Setting these corresponse to the `CallMsg` fields of StateQuery:
///      https://github.com/ethereum/go-ethereum/blob/fd5d2ef0a6d9eac7542ead4bfbc9b5f0f399eb10/interfaces.go#L134
/// @param chainId The chain ID of the chain where the StateQuery will be made.
/// @param blockNumber The block number of the chain where the StateQuery is made.
///        If blockNumber is 0, then the StateQuery is made at the latest avaliable
///        block.
/// @param fromAddress The address that is used as the 'from' StateQuery argument
///        (influencing msg.sender & tx.origin). If set to address(0) then the
///        call is made from address(0).
/// @param toAddress The address that is used as the 'to' StateQuery argument.
/// @param toCalldata The calldata that is used as the 'data' StateQuery argument.
/// @param result The result from executing the StateQuery.
struct StateQueryResponse {
    uint32 chainId;
    uint64 blockNumber;
    address fromAddress;
    address toAddress;
    bytes toCalldata;
    bytes result;
}

interface IStateQueryGateway {
    /// @notice The response currently being processed by the gateway.
    function currentResponse() external view returns (StateQueryResponse memory);
}

/// @title TelepathyAttestationVerifier
/// @author Succinct Labs
/// @notice Verifies messages using Telepathy StateQuery attestations.
contract TelepathyAttestationVerifier is IMessageVerifier, Initializable {
    using Message for bytes;

    /// @notice The address of the StateQueryGateway contract.
    address public stateQueryGateway;
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

    /// @param _stateQueryGateway The address of the StateQueryGateway contract on this chain.
    /// @param _sourceChainIds The chain IDs that this contract will verify messages from.
    /// @param _telepathyRouters The sending TelepathyRouters, one for each sourceChainId.
    function initialize(
        address _stateQueryGateway,
        uint32[] memory _sourceChainIds,
        address[] memory _telepathyRouters
    ) external initializer {
        stateQueryGateway = _stateQueryGateway;
        if (_sourceChainIds.length != _telepathyRouters.length) {
            revert InvalidSourceChainLength(_sourceChainIds.length);
        }
        for (uint32 i = 0; i < _sourceChainIds.length; i++) {
            telepathyRouters[_sourceChainIds[i]] = _telepathyRouters[i];
        }
    }

    function verifierType() external pure override returns (VerifierType) {
        return VerifierType.ATTESTATION_STATE_QUERY;
    }

    /// @notice Verifies messages using Telepathy StateQuery attestations.
    /// @dev The first argument will be the same as the response.result (in the expected case),
    ///      so it is better to just ignore it.
    /// @param _message The message to verify.
    function verify(bytes calldata, bytes calldata _message)
        external
        view
        override
        returns (bool)
    {
        StateQueryResponse memory response = IStateQueryGateway(stateQueryGateway).currentResponse();
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
