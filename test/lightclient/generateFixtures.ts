import * as fs from 'fs';

import { toHexString } from '@chainsafe/ssz';
import {
    StepCircuit,
    RotateCircuit,
    ConsensusClient,
    CircuitConfig,
    computeBitSum,
    hashBeaconBlockHeader,
    poseidonSyncCommittee,
    hashSyncCommittee
} from '@succinctlabs/telepathy-sdk';
import { ConfigManager } from '@succinctlabs/telepathy-sdk/config';

// Keep this in sync with what we actually use in the Solidity contracts
const FINALITY_THRESHHOLD = 350;

// This script generates a single fixture for the lightclient based
// on the most recent finalized block. The fixture can then be used in
// the Forge LightClientTest.

// To generate N many fixtures, run the following in bash:
//      for i in {1..N}; do yarn tsx generateFixtures.ts; done &
// these will all be ran sequentially.

async function main() {
    const config = new ConfigManager('../../../toml/goerli.toml', false);
    const client = new ConsensusClient(config.consensusRpc(config.sourceChain()));
    const update = await client.getTelepathyUpdate('finalized');
    const syncCommitteePoseidon = await poseidonSyncCommittee(update.currentSyncCommittee.pubkeys);
    const finalizedHeaderRoot = toHexString(hashBeaconBlockHeader(update.finalizedHeader));
    const nextSyncCommitteeSSZ = toHexString(hashSyncCommittee(update.nextSyncCommittee));
    const nextSyncCommitteePoseidon = await poseidonSyncCommittee(update.nextSyncCommittee.pubkeys);

    console.log('CONSTRUCTOR');
    console.log('Genesis Validators Root:', toHexString(update.genesisValidatorsRoot));
    console.log('Genesis Time:', update.genesisTime);
    console.log('Current Sync Committee Period:', Math.floor(update.attestedHeader.slot / 8192));
    console.log('Current Sync Committee Poseidon:', syncCommitteePoseidon.toString());
    console.log('');

    console.log('STEP');
    console.log('Attested Slot:', update.attestedHeader.slot);
    console.log('Finalized Slot:', update.finalizedHeader.slot);
    console.log('Participation:', computeBitSum(update.syncAggregate.syncCommitteeBits).toString());
    console.log('Finalized Header Root:', finalizedHeaderRoot);
    console.log('Execution State Root:', toHexString(update.executionStateRoot));
    console.log('');

    console.log('ROTATE');
    console.log('Next Sync Committee SSZ:', nextSyncCommitteeSSZ);
    console.log('Next Sync Committee Poseidon:', nextSyncCommitteePoseidon);
    console.log('');

    const stepConfig: CircuitConfig = {
        witnessExecutablePath: '/shared/telepathy/circuits/build/step_cpp/step',
        proverExecutablePath: '/shared/rapidsnark/build/prover',
        proverKeyPath: '/shared/telepathy/circuits/build/step_cpp/p2.zkey'
    };
    const stepCircuit = new StepCircuit(stepConfig);
    const stepInput = await stepCircuit.calculateInputs(update);
    const stepWitness = await stepCircuit.calculateWitness(stepInput);
    const stepProof = await stepCircuit.prove(stepWitness);
    console.log('Step Proof:');
    console.log(JSON.stringify(stepProof.proof, null, 4));
    console.log('Public Inputs Root:', stepInput.publicInputsRoot.toString());
    console.log('');

    const rotateConfig: CircuitConfig = {
        witnessExecutablePath: '/shared/telepathy/circuits/build/rotate_cpp/rotate',
        proverExecutablePath: '/shared/rapidsnark/build/prover',
        proverKeyPath: '/shared/telepathy/circuits/build/rotate_cpp/p2.zkey'
    };
    const rotateCircuit = new RotateCircuit(rotateConfig);
    const rotateInput = await rotateCircuit.calculateInputs(update);
    const rotateWitness = await rotateCircuit.calculateWitness(rotateInput);
    const rotateProof = await rotateCircuit.prove(rotateWitness, 'proof.json', 'public.json');
    console.log('Rotate Proof:');
    console.log(JSON.stringify(rotateProof.proof, null, 4));

    if (computeBitSum(update.syncAggregate.syncCommitteeBits) < FINALITY_THRESHHOLD) {
        console.log('Skipping fixture generation due to low participation');
        return;
    }

    const fixtureJSON: any = {
        initial: {
            genesisTime: update.genesisTime.toString(),
            genesisValidatorsRoot: toHexString(update.genesisValidatorsRoot),
            secondsPerSlot: 12,
            slotsPerPeriod: 8192,
            syncCommitteePeriod: Math.floor(update.attestedHeader.slot / 8192),
            syncCommitteePoseidon: syncCommitteePoseidon.toString()
        },
        step: {
            attestedSlot: update.attestedHeader.slot,
            finalizedSlot: update.finalizedHeader.slot,
            participation: computeBitSum(update.syncAggregate.syncCommitteeBits).toString(),
            finalizedHeaderRoot: finalizedHeaderRoot,
            executionStateRoot: toHexString(update.executionStateRoot),
            a: [stepProof.proof.pi_a[0].toString(), stepProof.proof.pi_a[1].toString()],
            b: [
                [stepProof.proof.pi_b[0][0].toString(), stepProof.proof.pi_b[0][1].toString()],
                [stepProof.proof.pi_b[1][0].toString(), stepProof.proof.pi_b[1][1].toString()]
            ],
            c: [stepProof.proof.pi_c[0].toString(), stepProof.proof.pi_c[1].toString()],
            inputs: [stepInput.publicInputsRoot.toString()]
        },
        rotate: {
            a: [rotateProof.proof.pi_a[0].toString(), rotateProof.proof.pi_a[1].toString()],
            b: [
                [rotateProof.proof.pi_b[0][0].toString(), rotateProof.proof.pi_b[0][1].toString()],
                [rotateProof.proof.pi_b[1][0].toString(), rotateProof.proof.pi_b[1][1].toString()]
            ],
            c: [rotateProof.proof.pi_c[0].toString(), rotateProof.proof.pi_c[1].toString()],
            syncCommitteeSSZ: nextSyncCommitteeSSZ,
            syncCommitteePoseidon: nextSyncCommitteePoseidon
        }
    };
    const fixture = JSON.stringify(fixtureJSON, null, 4);
    fs.writeFileSync('fixtures/slot' + update.attestedHeader.slot + '.json', fixture, 'utf8');
    console.log('generated fixture at fixtures/slot' + update.attestedHeader.slot + '.json');
}

main();
