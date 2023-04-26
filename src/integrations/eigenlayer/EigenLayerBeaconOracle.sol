pragma solidity 0.8.16;

import {ILightClient} from "src/lightclient/interfaces/ILightClient.sol";
import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {ILightClientUpdater} from "src/integrations/eigenlayer/ILightClientUpdater.sol";
import {EigenLayerBeaconOracleStorage} from
    "src/integrations/eigenlayer/EigenLayerBeaconOracleStorage.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract EigenLayerBeaconOracle is ILightClientUpdater, EigenLayerBeaconOracleStorage {
    uint256 internal constant EXECUTION_PAYLOAD_BLOCK_NUMBER_INDEX = 3222;
    uint256 internal constant BEACON_STATE_ROOT_INDEX = 11;

    event BeaconStateOracleUpdate(uint256 slot, uint256 blockNumber, bytes32 stateRoot);

    error InvalidBlockNumberProof();
    error InvalidBeaconStateRootProof();
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
        uint256 _slot,
        uint256 _blockNumber,
        bytes32[] calldata _blockNumberProof,
        bytes32 _beaconStateRoot,
        bytes32[] calldata _beaconStateRootProof
    ) external onlyWhitelistedUpdater {
        if (_slot <= head) {
            revert SlotNumberTooLow();
        }

        bytes32 blockHeaderRoot = ILightClient(lightclient).headers(_slot);

        // Verify block number against block header root
        if (!verifyBlockNumber(_blockNumber, _blockNumberProof, blockHeaderRoot)) {
            revert InvalidBlockNumberProof();
        }

        // Verify beacon state root against block header root
        if (!verifyBeaconStateRoot(_beaconStateRoot, _beaconStateRootProof, blockHeaderRoot)) {
            revert InvalidBeaconStateRootProof();
        }

        // Store the header root
        blockNumberToStateRoot[_blockNumber] = _beaconStateRoot;

        // Require that the slot number is greater than the previous slot number
        head = _slot;

        emit BeaconStateOracleUpdate(_slot, _blockNumber, _beaconStateRoot);
    }

    function verifyBlockNumber(
        uint256 _blockNumber,
        bytes32[] memory _blockNumberProof,
        bytes32 _blockHeaderRoot
    ) internal pure returns (bool) {
        return SSZ.isValidMerkleBranch(
            SSZ.toLittleEndian(_blockNumber),
            EXECUTION_PAYLOAD_BLOCK_NUMBER_INDEX,
            _blockNumberProof,
            _blockHeaderRoot
        );
    }

    function verifyBeaconStateRoot(
        bytes32 _beaconStateRoot,
        bytes32[] memory _beaconStateRootProof,
        bytes32 _blockHeaderRoot
    ) internal pure returns (bool) {
        return SSZ.isValidMerkleBranch(
            _beaconStateRoot, BEACON_STATE_ROOT_INDEX, _beaconStateRootProof, _blockHeaderRoot
        );
    }
}
