// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {ITelepathyHandler} from "src/amb-v2/interfaces/ITelepathy.sol";

abstract contract TelepathyHandler is ITelepathyHandler {
    error NotFromTelepathyRouter(address sender);

    address public telepathyRouter;

    constructor(address _telepathyRouter) {
        telepathyRouter = _telepathyRouter;
    }

    function handleTelepathy(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
        external
        override
        returns (bytes4)
    {
        if (msg.sender != telepathyRouter) {
            revert NotFromTelepathyRouter(msg.sender);
        }
        handleTelepathyImpl(_sourceChainId, _sourceAddress, _data);
        return ITelepathyHandler.handleTelepathy.selector;
    }

    function handleTelepathyImpl(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
        internal
        virtual;
}
