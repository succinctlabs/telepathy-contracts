pragma solidity 0.8.14;

import "src/lightclient/interfaces/ILightClient.sol";

interface IBroadcaster {
    event SentMessage(uint256 indexed nonce, bytes32 indexed msgHash, bytes message);
    event ShortSentMessage(uint256 indexed nonce, bytes32 indexed msgHash);

    function send(address receiver, uint16 chainId, uint256 gasLimit, bytes calldata data)
        external
        returns (bytes32);

    function sendViaLog(address receiver, uint16 chainId, uint256 gasLimit, bytes calldata data)
        external
        returns (bytes32);
}

enum MessageStatus {
    NOT_EXECUTED,
    EXECUTION_FAILED,
    EXECUTION_SUCCEEDED
}

struct Message {
    uint256 nonce;
    address sender;
    address receiver;
    uint16 chainId;
    uint256 gasLimit;
    bytes data;
}

interface IReciever {
    event ExecutedMessage(
        uint256 indexed nonce, bytes32 indexed msgHash, bytes message, bool status
    );

    function executeMessage(
        uint64 slot,
        bytes calldata message,
        bytes[] calldata accountProof,
        bytes[] calldata storageProof
    ) external;

    function executeMessageFromLog(
        bytes calldata srcSlotTxSlotPack,
        bytes calldata messageBytes,
        bytes32[] calldata receiptsRootProof,
        bytes32 receiptsRoot,
        bytes[] calldata receiptProof, // receipt proof against receipt root
        bytes memory txIndexRLPEncoded,
        uint256 logIndex
    ) external;
}
