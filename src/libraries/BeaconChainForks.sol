pragma solidity 0.8.16;

library BeaconChainForks {
    function getCapellaSlot(uint32 sourceChainId) internal pure returns (uint256) {
        // Returns CAPELLA_FORK_EPOCH * SLOTS_PER_EPOCH for the corresponding beacon chain.
        if (sourceChainId == 1) {
            // https://github.com/ethereum/consensus-specs/blob/dev/specs/capella/fork.md?plain=1#L30
            return 6209536;
        } else if (sourceChainId == 5) {
            // https://blog.ethereum.org/2023/03/08/goerli-shapella-announcement
            // https://github.com/eth-clients/goerli/blob/main/prater/config.yaml#L43
            return 5193728;
        } else {
            // We don't know the exact value for Gnosis Chain yet so we return max uint256
            // and fallback to bellatrix logic.
            return 2 ** 256 - 1;
        }
    }
}
