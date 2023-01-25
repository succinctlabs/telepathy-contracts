pragma solidity 0.8.14;

import "src/lightclient/interfaces/ILightClient.sol";

interface ITelepathyBroadcaster {
    event SentMessage(uint256 indexed nonce, bytes32 indexed msgHash, bytes message);

    function send(uint16 _recipientChainId, bytes32 _recipientAddress, bytes calldata _data)
        external
        returns (bytes32);

    function send(uint16 _recipientChainId, address _recipientAddress, bytes calldata _data)
        external
        returns (bytes32);

    function sendViaLog(uint16 _recipientChainId, bytes32 _recipientAddress, bytes calldata _data)
        external
        returns (bytes32);

    function sendViaLog(uint16 _recipientChainId, address _recipientAddress, bytes calldata _data)
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
    uint16 sourceChainId;
    address senderAddress;
    uint16 recipientChainId;
    bytes32 recipientAddress;
    bytes data;
}

interface ITelepathyReceiver {
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

interface ITelepathyHandler {
    function handleTelepathy(uint16 _sourceChainId, address _senderAddress, bytes memory _data)
        external;
}
