// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {ITelepathyRouterV2} from "src/amb-v2/interfaces/ITelepathy.sol";
import {TelepathyHandlerV2} from "src/amb-v2/interfaces/TelepathyHandler.sol";

/// @notice Example Counter that uses messaging to make a cross-chain increment call.
/// @dev Assumes that this contract is deployed at the same address on all chains.
contract CountMessenger is TelepathyHandlerV2 {
    uint256 public count;

    event Incremented(uint32 srcChainId, address sender);

    error NotFromCountMessenger(address sender);

    constructor(address _telepathyRouter) TelepathyHandlerV2(_telepathyRouter) {}

    /// @notice Sends a cross-chain increment message.
    function sendIncrement(uint32 _dstChainId) external {
        ITelepathyRouterV2(telepathyRouter).send(_dstChainId, address(this), "");
    }

    /// @notice Recieve a cross-chain increment message.
    function handleTelepathyImpl(uint32 _srcChainId, address _srcAddress, bytes memory)
        internal
        override
    {
        if (_srcAddress != address(this)) {
            revert NotFromCountMessenger(_srcAddress);
        }

        count++;

        emit Incremented(_srcChainId, _srcAddress);
    }
}
