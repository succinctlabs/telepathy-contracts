pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "./StepVerifier.sol";
import "./RotateVerifier.sol";
import "./libraries/SimpleSerialize.sol";
import "./interfaces/ILightClient.sol";

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

contract LightClient is ILightClient, StepVerifier, RotateVerifier {
    bytes32 public immutable GENESIS_VALIDATORS_ROOT;
    uint256 public immutable GENESIS_TIME;
    uint256 public immutable SECONDS_PER_SLOT;

    uint256 internal constant OPTIMISTIC_UPDATE_TIMEOUT = 86400;
    uint256 internal constant SLOTS_PER_EPOCH = 32;
    uint256 internal constant SLOTS_PER_SYNC_COMMITTEE_PERIOD = 8192;
    uint256 internal constant MIN_SYNC_COMMITTEE_PARTICIPANTS = 10;
    uint256 internal constant SYNC_COMMITTEE_SIZE = 512;
    uint256 internal constant FINALIZED_ROOT_INDEX = 105;
    uint256 internal constant NEXT_SYNC_COMMITTEE_INDEX = 55;
    uint256 internal constant EXECUTION_STATE_ROOT_INDEX = 402;

    bool public consistent = true;
    uint256 public head = 0;
    mapping(uint256 => bytes32) public headers;
    mapping(uint256 => bytes32) public executionStateRoots;
    mapping(uint256 => bytes32) public syncCommitteePoseidons;
    mapping(uint256 => LightClientRotate) public bestUpdates;

    event HeadUpdate(uint256 indexed slot, bytes32 indexed root);
    event SyncCommitteeUpdate(uint256 indexed period, bytes32 indexed root);

    constructor(
        bytes32 genesisValidatorsRoot,
        uint256 genesisTime,
        uint256 secondsPerSlot,
        uint256 syncCommitteePeriod,
        bytes32 syncCommitteePoseidon
    ) {
        GENESIS_VALIDATORS_ROOT = genesisValidatorsRoot;
        GENESIS_TIME = genesisTime;
        SECONDS_PER_SLOT = secondsPerSlot;
        setSyncCommitteePoseidon(syncCommitteePeriod, syncCommitteePoseidon);
    }

    /*
     * @dev Updates the head of the light client. The conditions for updating
     * involve checking the existence of:
     *   1) At least 2n/3+1 signatures from the current sync committee for n=512
     *   2) A valid finality proof
     *   3) A valid execution state root proof
     */
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

    /*
     * @dev Sets the sync committee validator set root for the next sync
     * committee period. This root is signed by the current sync committee. In
     * the case there is no finalization, we will keep track of the best
     * optimistic update.
     */
    function rotate(LightClientRotate memory update) external {
        LightClientStep memory step = update.step;
        bool finalized = processStep(update.step);
        uint256 currentPeriod = getSyncCommitteePeriod(step.finalizedSlot);
        uint256 nextPeriod = currentPeriod + 1;

        zkLightClientRotate(update);

        if (finalized) {
            setSyncCommitteePoseidon(nextPeriod, update.syncCommitteePoseidon);
        } else {
            LightClientRotate memory bestUpdate = bestUpdates[currentPeriod];
            if (step.participation < bestUpdate.step.participation) {
                revert("There exists a better update");
            }
            setBestUpdate(currentPeriod, update);
        }
    }

    /*
      * @dev In the case that there is no finalization for a sync committee
      * rotation, applies the update with the most signatures throughout the
      * period.
      */
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

    function getSyncCommitteePeriod(uint256 slot) internal pure returns (uint256) {
        return slot / SLOTS_PER_SYNC_COMMITTEE_PERIOD;
    }

    function getCurrentSlot() internal view returns (uint256) {
        return (block.timestamp - GENESIS_TIME) / SECONDS_PER_SLOT;
    }

    function setHead(uint256 slot, bytes32 root) internal {
        if (headers[slot] != bytes32(0) && headers[slot] != root) {
            consistent = false;
            return;
        }
        head = slot;
        headers[slot] = root;
        emit HeadUpdate(slot, root);
    }

    function setExecutionStateRoot(uint256 slot, bytes32 root) internal {
        if (executionStateRoots[slot] != bytes32(0) && executionStateRoots[slot] != root) {
            consistent = false;
            return;
        }
        executionStateRoots[slot] = root;
    }

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

    function setBestUpdate(uint256 period, LightClientRotate memory update) internal {
        bestUpdates[period] = update;
    }
}
