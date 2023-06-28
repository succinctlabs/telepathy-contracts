// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {ITelepathyHandlerV2} from "src/amb-v2/interfaces/ITelepathy.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

abstract contract TelepathyHandlerV2UpgradeableV2 is ITelepathyHandlerV2, Initializable {
    error NotFromTelepathyRouterV2(address sender);

    address public telepathyRouter;

    function __TelepathyHandlerV2_init(address _telepathyRouter) public onlyInitializing {
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
