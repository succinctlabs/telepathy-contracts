pragma solidity 0.8.16;

import {ITelepathyRouterV2} from "src/amb-v2/interfaces/ITelepathy.sol";
import {TelepathyHandlerV2} from "src/amb-v2/interfaces/TelepathyHandler.sol";

contract SourceCounter {
    ITelepathyRouterV2 router;
    uint32 targetChainId;

    constructor(address _router, uint32 _targetChainId) {
        router = ITelepathyRouterV2(_router);
        targetChainId = _targetChainId;
    }

    // Increment counter on target chain by given amount
    function increment(uint256 amount, address targetCounter) external payable virtual {
        bytes memory msgData = abi.encode(amount);
        router.send{value: msg.value}(targetChainId, targetCounter, msgData);
    }
}

contract TargetCounter is TelepathyHandlerV2 {
    uint256 public counter = 0;

    event Incremented(uint32 sourceChainId, address sender, uint256 amount);

    constructor(address _router) TelepathyHandlerV2(_router) {}

    // Handle messages being sent and decoding
    function handleTelepathyImpl(uint32 sourceChainId, address sender, bytes memory msgData)
        internal
        override
    {
        (uint256 amount) = abi.decode(msgData, (uint256));
        unchecked {
            counter = counter + amount;
        }
        emit Incremented(sourceChainId, sender, amount);
    }
}
