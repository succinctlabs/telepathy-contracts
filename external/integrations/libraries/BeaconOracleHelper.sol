pragma solidity 0.8.16;

import {SSZ} from "src/libraries/SimpleSerialize.sol";

library BeaconOracleHelper {
    /// @notice Beacon block constants
    uint256 internal constant BEACON_STATE_ROOT_INDEX = 11;
    uint256 internal constant BASE_DEPOSIT_INDEX = 6336;
    uint256 internal constant EXECUTION_PAYLOAD_BLOCK_NUMBER_INDEX = 3222;

    /// @notice Validator proof constants
    uint256 internal constant BASE_VALIDATOR_INDEX = 94557999988736;
    uint256 internal constant VALIDATOR_FIELDS_LENGTH = 8;
    uint256 internal constant PUBKEY_INDEX = 0;
    uint256 internal constant WITHDRAWAL_CREDENTIALS_INDEX = 1;
    uint256 internal constant EFFECTIVE_BALANCE_INDEX = 2;
    uint256 internal constant SLASHED_INDEX = 3;
    uint256 internal constant ACTIVATION_ELIGIBILITY_EPOCH_INDEX = 4;
    uint256 internal constant ACTIVATION_EPOCH_INDEX = 5;
    uint256 internal constant EXIT_EPOCH_INDEX = 6;
    uint256 internal constant WITHDRAWABLE_EPOCH_INDEX = 7;

    /// @notice Balance constants
    uint256 internal constant BASE_BALANCE_INDEX = 24189255811072;

    struct BeaconStateRootProofInfo {
        uint256 slot;
        bytes32 beaconStateRoot;
        bytes32[] beaconStateRootProof;
    }

    struct ValidatorProofInfo {
        uint256 validatorIndex;
        bytes32 validatorRoot;
        bytes32[] validatorProof;
    }

    struct Validator {
        bytes32 pubkey;
        bytes32 withdrawalCredentials;
        // Not to be confused with the validator's balance (effective balance capped at 32ETH)
        uint256 effectiveBalance;
        bool slashed;
        uint256 activationEligibilityEpoch;
        uint256 activationEpoch;
        uint256 exitEpoch;
        uint256 withdrawableEpoch;
    }

    enum ValidatorField {
        Pubkey,
        WithdrawalCredentials,
        // Not to be confused with the validator's balance (effective balance capped at 32ETH)
        EffectiveBalance,
        Slashed,
        ActivationEligibilityEpoch,
        ActivationEpoch,
        ExitEpoch,
        WithdrawableEpoch
    }

    function _verifyBlockNumber(
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

    function _verifyBeaconStateRoot(BeaconStateRootProofInfo calldata _beaconStateRootProofInfo, bytes32 _blockHeaderRoot)
        internal
        pure
        returns (bool)
    {
        return SSZ.isValidMerkleBranch(
            _beaconStateRootProofInfo.beaconStateRoot,
            BEACON_STATE_ROOT_INDEX,
            _beaconStateRootProofInfo.beaconStateRootProof,
            _blockHeaderRoot
        );
    }

    function _verifyValidatorRoot(
        ValidatorProofInfo calldata _validatorProofInfo,
        bytes32 _beaconStateRoot
    ) internal pure returns (bool) {
        return SSZ.isValidMerkleBranch(
            _validatorProofInfo.validatorRoot,
            BASE_VALIDATOR_INDEX + _validatorProofInfo.validatorIndex,
            _validatorProofInfo.validatorProof,
            _beaconStateRoot
        );
    }

    /// @notice Proves the gindex for the specified pubkey at _depositIndex
    function _verifyValidatorDeposited(
        uint256 _depositIndex,
        bytes32 _pubkeyHash,
        bytes32[] memory _depositedPubkeyProof,
        bytes32 _blockHeaderRoot
    ) internal pure returns (bool) {
        return SSZ.isValidMerkleBranch(
            _pubkeyHash,
            ((((BASE_DEPOSIT_INDEX + _depositIndex) * 2) + 1) * 4) + 0,
            _depositedPubkeyProof,
            _blockHeaderRoot
        );
    }

    function _verifyValidatorBalance(
        bytes32[] memory _balanceProof,
        uint256 _validatorIndex,
        bytes32 _combinedBalance,
        bytes32 _beaconStateRoot
    ) internal pure returns (bool) {
        return SSZ.isValidMerkleBranch(
            _combinedBalance, BASE_BALANCE_INDEX + _validatorIndex, _balanceProof, _beaconStateRoot
        );
    }

    /// @notice Proves a validator field against the validator root
    function _verifyValidatorField(
        bytes32 _validatorRoot,
        bytes32 _leaf,
        bytes32[] memory _validatorFieldProof,
        ValidatorField _field
    ) internal pure returns (bool) {
        return SSZ.isValidMerkleBranch(
                _leaf,
                _getFieldGIndex(_field),
                _validatorFieldProof,
                _validatorRoot
            );
    }

    /// @notice Validator balances are stored in an array of 4 64-bit integers, we extract the validator's balance
    function _getBalanceFromCombinedBalance(uint256 _validatorIndex, bytes32 _combinedBalance)
        internal
        pure
        returns (uint256)
    {
        uint256 modBalance = _validatorIndex % 4;

        bytes32 mask = bytes32(0xFFFFFFFFFFFFFFFF << ((3 - modBalance) * 64));
        bytes32 leBytes = (_combinedBalance & mask) << (modBalance * 64);
        uint256 result = 0;
        for (uint256 i = 0; i < leBytes.length; i++) {
            result += uint256(uint8(leBytes[i])) * 2 ** (8 * i);
        }
        return result;
    }

    /// @notice Returns the gindex for a validator field
    function _getFieldGIndex(ValidatorField _field)
        internal
        pure
        returns (uint256)
    {  
        if (_field == ValidatorField.Pubkey) {
            return VALIDATOR_FIELDS_LENGTH + PUBKEY_INDEX;
        } else if (_field == ValidatorField.WithdrawalCredentials) {
            return VALIDATOR_FIELDS_LENGTH + WITHDRAWAL_CREDENTIALS_INDEX;
        } else if (_field == ValidatorField.Slashed) {
            return VALIDATOR_FIELDS_LENGTH + SLASHED_INDEX;
        } else if (_field == ValidatorField.ActivationEligibilityEpoch) {
            return VALIDATOR_FIELDS_LENGTH + ACTIVATION_ELIGIBILITY_EPOCH_INDEX;
        } else if (_field == ValidatorField.ActivationEpoch) {
            return VALIDATOR_FIELDS_LENGTH + ACTIVATION_EPOCH_INDEX;
        } else if (_field == ValidatorField.ExitEpoch) {
            return VALIDATOR_FIELDS_LENGTH + EXIT_EPOCH_INDEX;
        } else {
            return VALIDATOR_FIELDS_LENGTH + WITHDRAWABLE_EPOCH_INDEX;
        }
    }
}