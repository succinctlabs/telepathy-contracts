pragma solidity 0.8.14;

import {SSZ} from "src/libraries/SimpleSerialize.sol";

import {ILightClient} from "./interfaces/ILightClient.sol";
import {StepVerifier} from "./StepVerifier.sol";
import {RotateVerifier} from "./RotateVerifier.sol";

struct Groth16Proof {
    uint256[2] a;
    uint256[2][2] b;
    uint256[2] c;
}

struct LightClientStep {
    uint256 finalizedSlot;
    uint256 participation;
    bytes32 finalizedHeaderRoot;
    bytes32 executionStateRoot;
    Groth16Proof proof;
}

struct LightClientRotate {
    LightClientStep step;
    bytes32 syncCommitteeSSZ;
    bytes32 syncCommitteePoseidon;
    Groth16Proof proof;
}

/// @title Light Client
/// @author Succinct Labs
/// @notice Uses Ethereum 2's Sync Committee Protocol to keep up-to-date with block headers from a
///         Beacon Chain. This is done in a gas-efficient manner using zero-knowledge proofs.
contract LightClient is ILightClient, StepVerifier, RotateVerifier {
    bytes32 public immutable GENESIS_VALIDATORS_ROOT;
    uint256 public immutable GENESIS_TIME;
    uint256 public immutable SECONDS_PER_SLOT;
    uint256 public immutable SLOTS_PER_PERIOD;

    uint256 internal constant MIN_SYNC_COMMITTEE_PARTICIPANTS = 10;
    uint256 internal constant SYNC_COMMITTEE_SIZE = 512;
    uint256 internal constant FINALIZED_ROOT_INDEX = 105;
    uint256 internal constant NEXT_SYNC_COMMITTEE_INDEX = 55;
    uint256 internal constant EXECUTION_STATE_ROOT_INDEX = 402;

    /// @notice Whether the light client has had two different headers validate for the same slot.
    bool public consistent = true;

    /// @notice The latest slot the light client has a finalized header for.
    uint256 public head = 0;

    /// @notice Maps from a slot to a beacon block header root.
    mapping(uint256 => bytes32) public headers;

    /// @notice Maps from a slot to the current finalized ethereum1 execution state root.
    mapping(uint256 => bytes32) public executionStateRoots;

    /// @notice Maps from a period to the poseidon commitment for the sync committee.
    mapping(uint256 => bytes32) public syncCommitteePoseidons;

    /// @notice Maps from a period to the rotate call with the most participation.
    mapping(uint256 => LightClientRotate) public bestUpdates;

    event HeadUpdate(uint256 indexed slot, bytes32 indexed root);
    event SyncCommitteeUpdate(uint256 indexed period, bytes32 indexed root);

    constructor(
        bytes32 genesisValidatorsRoot,
        uint256 genesisTime,
        uint256 secondsPerSlot,
        uint256 slotsPerPeriod,
        uint256 syncCommitteePeriod,
        bytes32 syncCommitteePoseidon
    ) {
        GENESIS_VALIDATORS_ROOT = genesisValidatorsRoot;
        GENESIS_TIME = genesisTime;
        SECONDS_PER_SLOT = secondsPerSlot;
        SLOTS_PER_PERIOD = slotsPerPeriod;
        setSyncCommitteePoseidon(syncCommitteePeriod, syncCommitteePoseidon);
    }

    /// @notice Updates the head of the light client to the provided slot.
    /// @dev The conditions for updating the head of the light client involve checking:
    ///      1) At least 2n/3+1 signatures from the current sync committee for n=512
    ///      2) A valid finality proof
    ///      3) A valid execution state root proof
    function step(LightClientStep memory update) external {
        bool finalized = processStep(update);

        if (getCurrentSlot() < update.finalizedSlot) {
            revert("Update slot is too far in the future");
        }

        if (finalized) {
            setHead(update.finalizedSlot, update.finalizedHeaderRoot);
            setExecutionStateRoot(update.finalizedSlot, update.executionStateRoot);
        }
    }

    /// @notice Sets the sync committee for the next sync committeee period.
    /// @dev A commitment to the the next sync committeee is signed by the current sync committee.
    ///      In the case there is no finalization, we will keep track of the best optimistic update
    ///      and then resolve at the end of the period.
    function rotate(LightClientRotate memory update) external {
        LightClientStep memory stepUpdate = update.step;
        bool finalized = processStep(update.step);
        uint256 currentPeriod = getSyncCommitteePeriod(stepUpdate.finalizedSlot);
        uint256 nextPeriod = currentPeriod + 1;

        zkLightClientRotate(update);

        if (finalized) {
            setSyncCommitteePoseidon(nextPeriod, update.syncCommitteePoseidon);
        } else {
            LightClientRotate memory bestUpdate = bestUpdates[currentPeriod];
            if (stepUpdate.participation < bestUpdate.step.participation) {
                revert("There exists a better update");
            }
            setBestUpdate(currentPeriod, update);
        }
    }

    /// @notice In the case there is no finalization for a sync committee rotation, this method
    ///         is used to apply the rotate update with the most signatures throughout the period.
    /// @param period The period for which we are trying to apply the best rotate update for.
    function force(uint256 period) external {
        LightClientRotate memory update = bestUpdates[period];
        uint256 nextPeriod = period + 1;

        if (update.step.finalizedHeaderRoot == 0) {
            revert("Best update was never initialized");
        } else if (syncCommitteePoseidons[nextPeriod] != 0) {
            revert("Sync committee for next period already initialized.");
        } else if (getSyncCommitteePeriod(getCurrentSlot()) < nextPeriod) {
            revert("Must wait for current sync committee period to end.");
        }

        setSyncCommitteePoseidon(nextPeriod, update.syncCommitteePoseidon);
    }

    /// @notice Verifies that the header has enough signatures for finality.
    function processStep(LightClientStep memory update) internal view returns (bool) {
        uint256 currentPeriod = getSyncCommitteePeriod(update.finalizedSlot);

        if (syncCommitteePoseidons[currentPeriod] == 0) {
            revert("Sync committee for current period is not initialized.");
        } else if (update.participation < MIN_SYNC_COMMITTEE_PARTICIPANTS) {
            revert("Less than MIN_SYNC_COMMITTEE_PARTICIPANTS signed.");
        }

        zkLightClientStep(update);

        return 3 * update.participation > 2 * SYNC_COMMITTEE_SIZE;
    }

    /// @notice Serializes the public inputs into a compressed form and verifies the step proof.
    function zkLightClientStep(LightClientStep memory update) internal view {
        bytes32 finalizedSlotLE = SSZ.toLittleEndian(update.finalizedSlot);
        bytes32 participationLE = SSZ.toLittleEndian(update.participation);
        uint256 currentPeriod = getSyncCommitteePeriod(update.finalizedSlot);
        bytes32 syncCommitteePoseidon = syncCommitteePoseidons[currentPeriod];

        bytes32 h;
        h = sha256(bytes.concat(finalizedSlotLE, update.finalizedHeaderRoot));
        h = sha256(bytes.concat(h, participationLE));
        h = sha256(bytes.concat(h, update.executionStateRoot));
        h = sha256(bytes.concat(h, syncCommitteePoseidon));
        uint256 t = uint256(SSZ.toLittleEndian(uint256(h)));
        t = t & ((uint256(1) << 253) - 1);

        Groth16Proof memory proof = update.proof;
        uint256[1] memory inputs = [uint256(t)];
        require(verifyProofStep(proof.a, proof.b, proof.c, inputs) == true);
    }

    /// @notice Serializes the public inputs and verifies the rotate proof.
    function zkLightClientRotate(LightClientRotate memory update) internal view {
        Groth16Proof memory proof = update.proof;
        uint256[65] memory inputs;

        uint256 syncCommitteeSSZNumeric = uint256(update.syncCommitteeSSZ);
        for (uint256 i = 0; i < 32; i++) {
            inputs[32 - 1 - i] = syncCommitteeSSZNumeric % 2 ** 8;
            syncCommitteeSSZNumeric = syncCommitteeSSZNumeric / 2 ** 8;
        }
        uint256 finalizedHeaderRootNumeric = uint256(update.step.finalizedHeaderRoot);
        for (uint256 i = 0; i < 32; i++) {
            inputs[64 - 1 - i] = finalizedHeaderRootNumeric % 2 ** 8;
            finalizedHeaderRootNumeric = finalizedHeaderRootNumeric / 2 ** 8;
        }
        inputs[64] = uint256(SSZ.toLittleEndian(uint256(update.syncCommitteePoseidon)));

        require(verifyProofRotate(proof.a, proof.b, proof.c, inputs) == true);
    }

    /// @notice Gets the sync committee period from a slot.
    function getSyncCommitteePeriod(uint256 slot) internal view returns (uint256) {
        return slot / SLOTS_PER_PERIOD;
    }

    /// @notice Gets the current slot for the chain the light client is reflecting.
    function getCurrentSlot() internal view returns (uint256) {
        return (block.timestamp - GENESIS_TIME) / SECONDS_PER_SLOT;
    }

    /// @notice Gets the current slot for the chain the light client is reflecting.
    function setHead(uint256 slot, bytes32 root) internal {
        if (headers[slot] != bytes32(0) && headers[slot] != root) {
            consistent = false;
            return;
        }
        head = slot;
        headers[slot] = root;
        emit HeadUpdate(slot, root);
    }

    /// @notice Sets the execution state root for a given slot.
    function setExecutionStateRoot(uint256 slot, bytes32 root) internal {
        if (executionStateRoots[slot] != bytes32(0) && executionStateRoots[slot] != root) {
            consistent = false;
            return;
        }
        executionStateRoots[slot] = root;
    }

    /// @notice Sets the sync committee poseidon for a given period.
    function setSyncCommitteePoseidon(uint256 period, bytes32 poseidon) internal {
        if (
            syncCommitteePoseidons[period] != bytes32(0)
                && syncCommitteePoseidons[period] != poseidon
        ) {
            consistent = false;
            return;
        }
        syncCommitteePoseidons[period] = poseidon;
        emit SyncCommitteeUpdate(period, poseidon);
    }

    /// @notice Sets the the best update for a given period.
    function setBestUpdate(uint256 period, LightClientRotate memory update) internal {
        bestUpdates[period] = update;
    }
}
