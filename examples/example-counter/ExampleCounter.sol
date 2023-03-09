pragma solidity 0.8.16;

import {ITelepathyRouter} from "src/amb/interfaces/ITelepathy.sol";
import {TelepathyHandler} from "src/amb/interfaces/TelepathyHandler.sol";

contract SourceCounter {
    ITelepathyRouter router;
    uint32 targetChainId;

    constructor(address _router, uint32 _targetChainId) {
        router = ITelepathyRouter(_router);
        targetChainId = _targetChainId;
    }

    // Increment counter on target chain by given amount
    function increment(uint256 amount, address targetCounter) external virtual {
        bytes memory msgData = abi.encode(amount);
        router.send(targetChainId, targetCounter, msgData);
    }
}

contract TargetCounter is TelepathyHandler {
    uint256 public counter = 0;

    constructor(address _router) TelepathyHandler(_router) {}

    // Handle messages being sent and decoding
    function handleTelepathyImpl(uint32 sourceChainId, address sender, bytes memory msgData)
        internal
        override
    {
        (uint256 amount) = abi.decode(msgData, (uint256));
        unchecked {
            counter = counter + amount;
        }
    }
}
