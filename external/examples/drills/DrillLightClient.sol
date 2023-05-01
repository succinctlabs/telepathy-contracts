pragma solidity 0.8.16;

import {LightClient} from "src/lightclient/LightClient.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/// @title DrillLightClient
/// @dev This contract is used solely for testing purposes and should not be used by production contracts.
contract DrillLightClient is LightClient, Ownable {
    constructor(address emitter) LightClient(0, 0, 0, 0, 0, 0, 0, 0) Ownable() {
        transferOwnership(emitter);
    }

    function emitFakeHeadUpdateEvent(uint256 _slot, bytes32 _root) external onlyOwner {
        emit HeadUpdate(_slot, _root);
    }

    function emitFakeSyncCommitteeUpdateEvent(uint256 _period, bytes32 _root) external onlyOwner {
        emit SyncCommitteeUpdate(_period, _root);
    }
}
