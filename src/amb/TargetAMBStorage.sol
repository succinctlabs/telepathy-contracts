pragma solidity 0.8.14;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {MessageStatus} from "./interfaces/ITelepathy.sol";

contract TargetAMBStorage {
    /// @notice The reference light client contract.
    ILightClient public lightClient;

    /// @notice Mapping between a message root and its status.
    mapping(bytes32 => MessageStatus) public messageStatus;

    /// @notice Address of the Telepathy broadcaster on the source chain.
    address public broadcaster;

    /// @notice Whether or not the contract is frozen.
    bool public frozen;
}
