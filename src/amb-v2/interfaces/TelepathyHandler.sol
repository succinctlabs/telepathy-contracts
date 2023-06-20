// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {ITelepathyHandlerV2} from "src/amb-v2/interfaces/ITelepathy.sol";

abstract contract TelepathyHandlerV2 is ITelepathyHandlerV2 {
    error NotFromTelepathyRouterV2(address sender);

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
            revert NotFromTelepathyRouterV2(msg.sender);
        }
        handleTelepathyImpl(_sourceChainId, _sourceAddress, _data);
        return ITelepathyHandlerV2.handleTelepathy.selector;
    }

    function handleTelepathyImpl(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
        internal
        virtual;
}
