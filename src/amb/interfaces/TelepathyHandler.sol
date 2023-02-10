pragma solidity ^0.8.0;

import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

import {ITelepathyHandler} from "./ITelepathy.sol";

abstract contract TelepathyHandler is ITelepathyHandler {
    error NotFromTelepathyReceiever(address sender);

    address private _telepathyReceiever;

    constructor(address telepathyReceiever) {
        _telepathyReceiever = telepathyReceiever;
    }

    function rawHandleTelepathy(uint16 _sourceChainId, address _senderAddress, bytes memory _data)
        external
        override
    {
        if (msg.sender != _telepathyReceiever) {
            revert NotFromTelepathyReceiever(msg.sender);
        }
        handleTelepathy(_sourceChainId, _senderAddress, _data);
    }

    function handleTelepathy(uint16 _sourceChainId, address _senderAddress, bytes memory _data)
        internal
        virtual;
}

abstract contract TelepathyHandlerUpgradeable is ITelepathyHandler, Initializable {
    error NotFromTelepathyReceiever(address sender);

    address private _telepathyReceiever;

    function __TelepathyHandler_init(address telepathyReceiever) public onlyInitializing {
        _telepathyReceiever = telepathyReceiever;
    }

    function rawHandleTelepathy(uint16 _sourceChainId, address _senderAddress, bytes memory _data)
        external
        override
    {
        if (msg.sender != _telepathyReceiever) {
            revert NotFromTelepathyReceiever(msg.sender);
        }
        handleTelepathy(_sourceChainId, _senderAddress, _data);
    }

    function handleTelepathy(uint16 _sourceChainId, address _senderAddress, bytes memory _data)
        internal
        virtual;
}
