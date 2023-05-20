pragma solidity 0.8.16;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {ILightClientUpdater} from "external/integrations/eigenlayer/ILightClientUpdater.sol";
import {BeaconOracleHelper} from "external/integrations/libraries/BeaconOracleHelper.sol";
import {EigenLayerBeaconOracleStorage} from
    "external/integrations/eigenlayer/EigenLayerBeaconOracleStorage.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

contract EigenLayerBeaconOracle is ILightClientUpdater, EigenLayerBeaconOracleStorage {
    event BeaconStateOracleUpdate(uint256 slot, uint256 blockNumber, bytes32 stateRoot);

    error InvalidUpdater(address updater);
    error SlotNumberTooLow();

    modifier onlyWhitelistedUpdater() {
        if (!whitelistedOracleUpdaters[msg.sender]) {
            revert InvalidUpdater(msg.sender);
        }
        _;
    }

    function getBeaconStateRoot(uint256 _blockNumber) external view returns (bytes32) {
        return blockNumberToStateRoot[_blockNumber];
    }

    function fulfillRequest(
        BeaconOracleHelper.BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        uint256 _blockNumber,
        bytes32[] calldata _blockNumberProof
    ) external onlyWhitelistedUpdater {
        if (_beaconStateRootProofInfo.slot <= head) {
            revert SlotNumberTooLow();
        }

        bytes32 blockHeaderRoot = ILightClient(lightclient).headers(_beaconStateRootProofInfo.slot);

        // Verify block number against block header root
        BeaconOracleHelper._verifyBlockNumber(_blockNumber, _blockNumberProof, blockHeaderRoot);

        // Verify beacon state root against block header root
        BeaconOracleHelper._verifyBeaconStateRoot(_beaconStateRootProofInfo, blockHeaderRoot);

        // Store the header root
        blockNumberToStateRoot[_blockNumber] = _beaconStateRootProofInfo.beaconStateRoot;

        // Require that the slot number is greater than the previous slot number
        head = _beaconStateRootProofInfo.slot;

        emit BeaconStateOracleUpdate(
            _beaconStateRootProofInfo.slot, _blockNumber, _beaconStateRootProofInfo.beaconStateRoot
        );
    }
}
