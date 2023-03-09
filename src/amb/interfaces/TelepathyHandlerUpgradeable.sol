pragma solidity ^0.8.0;

import {ITelepathyHandler} from "./ITelepathy.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract TelepathyHandlerUpgradeable is ITelepathyHandler, Initializable {
    error NotFromTelepathyReceiever(address sender);

    address private _telepathyReceiever;

    function __TelepathyHandler_init(address telepathyReceiever) public onlyInitializing {
        _telepathyReceiever = telepathyReceiever;
    }

    function handleTelepathy(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
        external
        override
        returns (bytes4)
    {
        if (msg.sender != _telepathyReceiever) {
            revert NotFromTelepathyReceiever(msg.sender);
        }
        handleTelepathyImpl(_sourceChainId, _sourceAddress, _data);
        return ITelepathyHandler.handleTelepathy.selector;
    }

    function handleTelepathyImpl(uint32 _sourceChainId, address _sourceAddress, bytes memory _data)
        internal
        virtual;
}
