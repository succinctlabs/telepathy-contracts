pragma solidity 0.8.14;

import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";

contract Timelock is TimelockController {
    /**
     * @dev Initializes the contract with the following parameters:
     *
     * - `minDelay`: initial minimum delay for operations
     * - `proposers`: accounts to be granted proposer and canceller roles
     * - `executors`: accounts to be granted executor role
     * - `admin`: optional account to be granted admin role; disable with zero address
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}

    /// @inheritdoc TimelockController
    function _execute(address target, uint256 value, bytes calldata data) internal override {
        (bool success,) = target.call{value: value}(data);
    }
}
