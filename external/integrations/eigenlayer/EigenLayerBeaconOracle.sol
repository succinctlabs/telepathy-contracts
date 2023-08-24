pragma solidity ^0.8.16;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {BeaconOracleHelper} from "external/integrations/libraries/BeaconOracleHelper.sol";
import {EigenLayerBeaconOracleStorage} from
    "external/integrations/eigenlayer/EigenLayerBeaconOracleStorage.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

contract EigenLayerBeaconOracle is EigenLayerBeaconOracleStorage {
    event EigenLayerBeaconOracleUpdate(uint256 slot, uint256 timestamp, bytes32 blockRoot);

    error InvalidUpdater(address updater);
    error SlotNumberTooLow();

    modifier onlyWhitelistedUpdater() {
        if (!whitelistedOracleUpdaters[msg.sender]) {
            revert InvalidUpdater(msg.sender);
        }
        _;
    }

    /// @notice Get beacon block root for the given timestamp
    function getBeaconBlockRoot(uint256 _timestamp) external view returns (bytes32) {
        return timestampToBlockRoot[_timestamp];
    }

    /// @notice Fulfill request for a given timestamp (associated with a block)
    function fulfillRequest(
        BeaconOracleHelper.BeaconStateRootProofInfo calldata _sourceBeaconStateRootProofInfo,
        BeaconOracleHelper.TargetBeaconBlockRootProofInfo calldata _targetBeaconBlockRootProofInfo,
        bytes32[] calldata _targetTimestampProof,
        uint256 _targetTimestamp
    ) external onlyWhitelistedUpdater {
        // Get the source beacon block header root.
        bytes32 sourceHeaderRoot = ILightClient(lightclient).headers(
            _sourceBeaconStateRootProofInfo.slot
        );

        // Extract the source beacon state root.
        BeaconOracleHelper.verifyBeaconStateRoot(
            _sourceBeaconStateRootProofInfo,
            sourceHeaderRoot
        );

        // Verify the target beacon block root.
        bytes32 sourceBeaconStateRoot = _sourceBeaconStateRootProofInfo.beaconStateRoot;
        BeaconOracleHelper.verifyTargetBeaconBlockRoot(
            _targetBeaconBlockRootProofInfo,
            sourceBeaconStateRoot
        );

        // Verify timestamp against target block header root.
        bytes32 targetBeaconBlockRoot = _targetBeaconBlockRootProofInfo.targetBeaconBlockRoot;
        BeaconOracleHelper.verifyTimestamp(
            _targetTimestamp,
            _targetTimestampProof,
            targetBeaconBlockRoot
        );

        // Store the target block header root
        timestampToBlockRoot[_targetTimestamp] = targetBeaconBlockRoot;

        // Emit the event.
        emit EigenLayerBeaconOracleUpdate(
            _targetBeaconBlockRootProofInfo.targetSlot,
            _targetTimestamp,
            targetBeaconBlockRoot
        );
    }
}
