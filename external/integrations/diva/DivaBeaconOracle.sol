// SPDX-License-Identifier: MIT
// Adapted from Succint Labs contract (https://github.com/succinctlabs/telepathy-contracts/blob/main/external/integrations/diva/DivaBeaconOracle.sol)
pragma solidity ^0.8.16;

import {SSZ} from "src/libraries/SSZ.sol";
import {BeaconProofHelper} from "src/libraries/BeaconProofHelper.sol";
import {BeaconRoot} from "src/libraries/BeaconRoot.sol";

library BeaconProofs {
    /// @notice Prove pubkey against deposit in beacon block
    function proveWithdrawal(
        uint64 _slot,
        uint256 _validatorIndex,
        uint256 _amount,
        // Index of deposit in deposit tree (MAX_LENGTH = 16)
        uint256 _withdrawalIndex,
        bytes32[] memory _withdrawalValidatorIndexProof,
        bytes32[] memory _withdrawalAmountProof,
        uint256 genesisBlockTimestamp
    ) external returns (uint256 amount) {
        bytes32 blockHeaderRoot = BeaconRoot.findBlockRoot(_slot, genesisBlockTimestamp);

        BeaconProofHelper.verifyValidatorWithdrawal(
            _withdrawalIndex,
            _validatorIndex,
            _amount,
            _withdrawalValidatorIndexProof,
            _withdrawalAmountProof,
            blockHeaderRoot
        );

        amount = _amount;
    }

    /// @notice Prove pubkey, withdrawal credentials
    function proveValidatorField(
        BeaconProofHelper.BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        BeaconProofHelper.ValidatorProofInfo calldata _validatorProofInfo,
        // Prove fields that are bytes32
        bytes32 _validatorFieldLeaf,
        bytes32[] calldata _validatorFieldProof,
        BeaconProofHelper.ValidatorField _field,
        uint256 genesisBlockTimestamp
    ) external {
        bytes32 blockHeaderRoot = BeaconRoot.findBlockRoot(_beaconStateRootProofInfo.slot, genesisBlockTimestamp);

        BeaconProofHelper.verifyValidatorRoot(_beaconStateRootProofInfo, _validatorProofInfo, blockHeaderRoot);
        BeaconProofHelper.verifyValidatorField(
            _validatorProofInfo.validatorRoot,
            _validatorProofInfo.validatorIndex,
            _validatorFieldLeaf,
            _validatorFieldProof,
            _field
        );
    }

    /// @notice Prove slashed & status epochs
    function proveValidatorField(
        BeaconProofHelper.BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        BeaconProofHelper.ValidatorProofInfo calldata _validatorProofInfo,
        // Prove fields that are uint256 or bool
        uint64 _validatorFieldLeaf,
        bytes32[] calldata _validatorFieldProof,
        BeaconProofHelper.ValidatorField _field,
        uint256 genesisBlockTimestamp
    ) external {
        bytes32 blockHeaderRoot = BeaconRoot.findBlockRoot(_beaconStateRootProofInfo.slot, genesisBlockTimestamp);

        BeaconProofHelper.verifyValidatorRoot(_beaconStateRootProofInfo, _validatorProofInfo, blockHeaderRoot);

        BeaconProofHelper.verifyValidatorField(
            _validatorProofInfo.validatorRoot,
            _validatorProofInfo.validatorIndex,
            SSZ.toLittleEndian(_validatorFieldLeaf),
            _validatorFieldProof,
            _field
        );
    }

    /// @notice Prove slashed & status epochs
    function proveValidatorFields(
        BeaconProofHelper.BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        BeaconProofHelper.ValidatorProofInfo calldata _validatorProofInfo,
        // Prove fields that are uint256 or bool
        bytes32[] calldata _validatorFields,
        uint256 genesisBlockTimestamp
    ) external {
        bytes32 blockHeaderRoot = BeaconRoot.findBlockRoot(_beaconStateRootProofInfo.slot, genesisBlockTimestamp);

        BeaconProofHelper.verifyValidatorRoot(_beaconStateRootProofInfo, _validatorProofInfo, blockHeaderRoot);

        BeaconProofHelper.verifyValidatorFields(_validatorProofInfo.validatorRoot, _validatorFields);
    }

    /// @notice Proves the balance of a validator against balances array
    function proveValidatorBalance(
        BeaconProofHelper.BeaconStateRootProofInfo calldata _beaconStateRootProofInfo,
        BeaconProofHelper.ValidatorProofInfo calldata _validatorProofInfo,
        // Combined balances of 4 validators packed into same gindex
        bytes32 _combinedBalance,
        bytes32[] calldata _balanceProof,
        uint256 genesisBlockTimestamp
    ) external returns (uint256 balance) {
        bytes32 blockHeaderRoot = BeaconRoot.findBlockRoot(_beaconStateRootProofInfo.slot, genesisBlockTimestamp);

        BeaconProofHelper.verifyValidatorRoot(_beaconStateRootProofInfo, _validatorProofInfo, blockHeaderRoot);

        balance = BeaconProofHelper.proveValidatorBalance(
            _validatorProofInfo.validatorIndex,
            _beaconStateRootProofInfo.beaconStateRoot,
            _combinedBalance,
            _balanceProof
        );
    }
}
