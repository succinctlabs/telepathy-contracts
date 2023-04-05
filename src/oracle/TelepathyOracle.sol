pragma solidity ^0.8.16;

import {TelepathyHandler} from "src/amb/interfaces/TelepathyHandler.sol";
import {IOracleCallbackReceiver} from "src/oracle/interfaces/IOracleCallbackReceiver.sol";

enum RequestStatus {
    UNSENT,
    PENDING,
    SUCCESS,
    FAILED
}

struct RequestData {
    uint256 nonce;
    address targetContract;
    bytes targetCalldata;
    address callbackContract;
}

contract TelepathyOracle is TelepathyHandler {
    event CrossChainRequestSent(
        uint256 indexed nonce,
        address targetContract,
        bytes targetCalldata,
        address callbackContract
    );

    error InvalidChainId(uint256 sourceChain);
    error NotFulfiller(address srcAddress);
    error RequestNotPending(bytes32 requestHash);

    /// @notice Maps request hashes to their status
    /// @dev The hash of a request is keccak256(abi.encode(RequestData))
    mapping(bytes32 => RequestStatus) public requests;
    /// @notice The next nonce to use when sending a cross-chain request
    uint256 public nextNonce = 1;
    /// @notice The address of the fulfiller contract on the other chain
    address public fulfiller;
    /// @notice The chain ID of the fulfiller contract
    uint32 public fulfillerChainId;

    constructor(uint32 _fulfillerChainId, address _telepathyRouter, address _fulfiller)
        TelepathyHandler(_telepathyRouter)
    {
        fulfillerChainId = _fulfillerChainId;
        fulfiller = _fulfiller;
    }

    function requestCrossChain(
        address _targetContract,
        bytes calldata _targetCalldata,
        address _callbackContract
    ) external returns (uint256 nonce) {
        unchecked {
            nonce = nextNonce++;
        }
        RequestData memory requestData =
            RequestData(nonce, _targetContract, _targetCalldata, _callbackContract);
        bytes32 requestHash = keccak256(abi.encode(requestData));
        requests[requestHash] = RequestStatus.PENDING;

        emit CrossChainRequestSent(nonce, _targetContract, _targetCalldata, _callbackContract);
        return nonce;
    }

    function handleTelepathyImpl(uint32 _sourceChain, address _senderAddress, bytes memory _data)
        internal
        override
    {
        if (_sourceChain != fulfillerChainId) {
            revert InvalidChainId(_sourceChain);
        }
        if (_senderAddress != fulfiller) {
            revert NotFulfiller(_senderAddress);
        }

        (
            uint256 nonce,
            bytes32 requestHash,
            address callbackContract,
            bytes memory responseData,
            bool responseSuccess
        ) = abi.decode(_data, (uint256, bytes32, address, bytes, bool));

        if (requests[requestHash] != RequestStatus.PENDING) {
            revert RequestNotPending(requestHash);
        }

        requests[requestHash] = responseSuccess ? RequestStatus.SUCCESS : RequestStatus.FAILED;

        callbackContract.call(
            abi.encodeWithSelector(
                IOracleCallbackReceiver.handleOracleResponse.selector,
                nonce,
                responseData,
                responseSuccess
            )
        );
    }
}
