pragma solidity 0.8.16;

// import "openzeppelin-contracts/access/Ownable.sol";
import {ITelepathyRouter} from "src/amb/interfaces/ITelepathy.sol";
import {TelepathyHandler} from "src/amb/interfaces/TelepathyHandler.sol";

contract SourceCounter {
    ITelepathyRouter router;
    uint32 targetChainId;

    // Useful for indexing on subgraph
    event SourceIncrement(uint32 targetChainId, address indexed from, uint256 amount);

    constructor(address _router, uint32 _targetChainId) {
        router = ITelepathyRouter(_router);
        targetChainId = _targetChainId;
    }

    // Increment counter on target chain by given amount
    function increment(uint256 amount, address targetCounter) external virtual {
        bytes memory msgData = abi.encode(amount);
        router.send(targetChainId, targetCounter, msgData);
        emit SourceIncrement(targetChainId, msg.sender, amount);
    }
}

contract TargetCounter is TelepathyHandler {
    uint256 public counter = 0;
    TelepathyHandler router;

    // Useful for indexing on subgraph
    event TargetIncrement(uint32 indexed sourceChainId, address indexed sender, uint256 amount);

    constructor(address _router) TelepathyHandler(_router) {
        router = TelepathyHandler(_router);
    }

    // Handle messages being sent and decoding
    function handleTelepathyImpl(uint32 sourceChainId, address sender, bytes memory msgData)
        internal
        override
    {
        require(msg.sender == address(router), "Sender is not router");
        (uint256 amount) = abi.decode(msgData, (uint256));
        unchecked {
            counter = counter + amount;
        }
        emit TargetIncrement(sourceChainId, sender, amount);
    }
}
