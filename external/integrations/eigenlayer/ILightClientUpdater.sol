// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.16;

/**
 * @title Interface for a contract that updates the telepathy light client.
 */
interface ILightClientUpdater {
    /**
     * @notice Fetches the beacon state root and prover address for the given block number from the Telepathy Light Client contract.
     * @param blockNumber The block number to update the light client with.
     * @return The beacon state root.
     */
    function getBeaconStateRoot(uint256 blockNumber) external view returns (bytes32);
}
