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
import { toHexString } from '@chainsafe/ssz';

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
    console.log('Current Sync Committee Poseidon:', syncCommitteePoseidon);
    console.log('');

    console.log('STEP');
    console.log('Attested Slot:', update.attestedHeader.slot);
    console.log('Finalized Slot:', update.finalizedHeader.slot);
    console.log('Participation:', computeBitSum(update.syncAggregate.syncCommitteeBits));
    console.log('Finalized Header Root:', finalizedHeaderRoot);
    console.log('Execution State Root:', toHexString(update.executionStateRoot));
    console.log('');

    console.log('ROTATE');
    console.log('Next Sync Committee SSZ:', nextSyncCommitteeSSZ);
    console.log('Next Sync Committee Poseidon:', nextSyncCommitteePoseidon);
    console.log('');

    const stepConfig: CircuitConfig = {
        witnessExecutablePath: '../../../circuits/build/step_cpp/step',
        proverExecutablePath: '~/rapidsnark/build/prover',
        proverKeyPath: '../../../circuits/build/step_cpp/p2.zkey'
    };
    const stepCircuit = new StepCircuit(stepConfig);
    const stepInput = await stepCircuit.calculateInputs(update);
    const stepWitness = await stepCircuit.calculateWitness(stepInput);
    const stepProof = await stepCircuit.prove(stepWitness);
    console.log('Step Proof:');
    console.log(JSON.stringify(stepProof.proof, null, 4));
    console.log('Public Inputs Root:', stepInput.publicInputsRoot);
    console.log('');

    const rotateConfig: CircuitConfig = {
        witnessExecutablePath: '../../../circuits/build/rotate_cpp/rotate',
        proverExecutablePath: '~/rapidsnark/build/prover',
        proverKeyPath: '../../../circuits/build/rotate_cpp/p2.zkey'
    };
    const rotateCircuit = new RotateCircuit(rotateConfig);
    const rotateInput = await rotateCircuit.calculateInputs(update);
    const rotateWitness = await rotateCircuit.calculateWitness(rotateInput);
    const rotateProof = await rotateCircuit.prove(rotateWitness, 'proof.json', 'public.json');
    console.log('Rotate Proof:');
    console.log(JSON.stringify(rotateProof.proof, null, 4));
}

main();
