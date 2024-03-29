pragma solidity 0.8.16;

import "forge-std/Base.sol";
import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {
    LightClient,
    Groth16Proof,
    LightClientStep,
    LightClientRotate,
    LightClientOptimizedRotate
} from "src/lightclient/LightClient.sol";

/// @notice Helper contract for parsing the JSON fixture, and converting them to the correct types.
/// @dev    The weird ordering here is because vm.parseJSON require alphabetical ordering of the
///         fields in the struct, and odd types with conversions are due to the way the JSON is
///         handled.
contract OptLightClientFixture is CommonBase {
    struct OptFixture {
        Initial initial;
        OptimizedRotate optimizedRotate;
        Rotate rotate;
        Step step;
    }

    struct Initial {
        bytes genesisTime;
        bytes32 genesisValidatorsRoot;
        uint256 secondsPerSlot;
        uint256 slotsPerPeriod;
        uint256 syncCommitteePeriod;
        string syncCommitteePoseidon;
    }

    struct Step {
        string[] a;
        uint256 attestedSlot;
        string[][] b;
        string[] c;
        bytes32 executionStateRoot;
        bytes32 finalizedHeaderRoot;
        uint256 finalizedSlot;
        string[] inputs;
        string participation;
    }

    struct Rotate {
        string[] a;
        string[][] b;
        string[] c;
        string syncCommitteePoseidon;
        bytes32 syncCommitteeSSZ;
    }

    struct OptimizedRotate {
        string[] a;
        string[][] b;
        string[] c;
        string publicInputsRoot;
        string syncCommitteePoseidon;
        bytes32 syncCommitteeSSZ;
    }

    function newOptLightClient(
        Initial memory initial,
        uint32 sourceChainId,
        uint16 finalityThreshold
    ) public returns (LightClient) {
        return new LightClient(
            initial.genesisValidatorsRoot,
            strToUint(string(initial.genesisTime)),
            initial.secondsPerSlot,
            initial.slotsPerPeriod,
            initial.syncCommitteePeriod,
            SSZ.toLittleEndian(strToUint(initial.syncCommitteePoseidon)),
            sourceChainId,
            finalityThreshold
        );
    }

    function convertToGroth16Proof(Step memory step) public pure returns (Groth16Proof memory) {
        uint256[2] memory a = [strToUint(step.a[0]), strToUint(step.a[1])];
        uint256[2][2] memory b = [
            [strToUint(step.b[0][1]), strToUint(step.b[0][0])],
            [strToUint(step.b[1][1]), strToUint(step.b[1][0])]
        ];
        uint256[2] memory c = [strToUint(step.c[0]), strToUint(step.c[1])];

        return Groth16Proof(a, b, c);
    }

    function convertToGroth16Proof(Rotate memory rotate)
        public
        pure
        returns (Groth16Proof memory)
    {
        uint256[2] memory a = [strToUint(rotate.a[0]), strToUint(rotate.a[1])];
        uint256[2][2] memory b = [
            [strToUint(rotate.b[0][1]), strToUint(rotate.b[0][0])],
            [strToUint(rotate.b[1][1]), strToUint(rotate.b[1][0])]
        ];
        uint256[2] memory c = [strToUint(rotate.c[0]), strToUint(rotate.c[1])];

        return Groth16Proof(a, b, c);
    }

    function convertToGroth16Proof(OptimizedRotate memory optimizedRotate)
        public
        pure
        returns (Groth16Proof memory)
    {
        uint256[2] memory a = [strToUint(optimizedRotate.a[0]), strToUint(optimizedRotate.a[1])];
        uint256[2][2] memory b = [
            [strToUint(optimizedRotate.b[0][1]), strToUint(optimizedRotate.b[0][0])],
            [strToUint(optimizedRotate.b[1][1]), strToUint(optimizedRotate.b[1][0])]
        ];
        uint256[2] memory c = [strToUint(optimizedRotate.c[0]), strToUint(optimizedRotate.c[1])];

        return Groth16Proof(a, b, c);
    }

    function convertToLightClientStep(Step memory step)
        public
        pure
        returns (LightClientStep memory)
    {
        return LightClientStep(
            step.attestedSlot,
            step.finalizedSlot,
            strToUint(step.participation),
            step.finalizedHeaderRoot,
            step.executionStateRoot,
            convertToGroth16Proof(step)
        );
    }

    function convertToLightClientRotate(Step memory step, Rotate memory rotate)
        public
        pure
        returns (LightClientRotate memory)
    {
        return LightClientRotate(
            convertToLightClientStep(step),
            rotate.syncCommitteeSSZ,
            SSZ.toLittleEndian(strToUint(rotate.syncCommitteePoseidon)),
            convertToGroth16Proof(rotate)
        );
    }

    function convertToLightClientOptimizedRotate(
        Step memory step,
        OptimizedRotate memory optimizedRotate
    ) public pure returns (LightClientOptimizedRotate memory) {
        return LightClientOptimizedRotate(
            convertToLightClientStep(step),
            optimizedRotate.syncCommitteeSSZ,
            SSZ.toLittleEndian(strToUint(optimizedRotate.syncCommitteePoseidon)),
            convertToGroth16Proof(optimizedRotate)
        );
    }

    function strToUint(string memory str) internal pure returns (uint256 res) {
        for (uint256 i = 0; i < bytes(str).length; i++) {
            if ((uint8(bytes(str)[i]) - 48) < 0 || (uint8(bytes(str)[i]) - 48) > 9) {
                revert();
            }
            res += (uint8(bytes(str)[i]) - 48) * 10 ** (bytes(str).length - i - 1);
        }

        return res;
    }
}
