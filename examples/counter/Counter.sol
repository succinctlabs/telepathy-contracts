pragma solidity 0.8.16;

import {ITelepathyRouter, ITelepathyHandler} from "src/amb/interfaces/ITelepathy.sol";

contract Counter is ITelepathyHandler {
    uint256 public counter = 0;
    address public router;

    event Incremented(uint32 indexed sourceChainId, address indexed sender);

    constructor(address _router) {
        router = _router;
    }

    function handleTelepathy(uint32 sourceChainId, address sender, bytes memory)
        public
        returns (bytes4)
    {
        require(msg.sender == address(router), "Sender is not router");
        counter = counter + 1;
        emit Incremented(sourceChainId, sender);
        return ITelepathyHandler.handleTelepathy.selector;
    }
}
