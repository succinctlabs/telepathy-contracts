import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

import { toHexString } from '@chainsafe/ssz';
import type { Provider } from '@ethersproject/providers';
import { ssz } from '@lodestar/types';
import { getExecuteByReceiptTx } from '@succinctlabs/telepathy-relayer/receiptProof';
import { Relayer } from '@succinctlabs/telepathy-relayer/relayer';
import {
    getExecuteByStorageTx,
    getBlockStateRoot,
    getStorageSlotFromNonce
} from '@succinctlabs/telepathy-relayer/storageProof';
import { ConsensusClient } from '@succinctlabs/telepathy-sdk';
import { ConfigManager, Service, ChainId, ContractId } from '@succinctlabs/telepathy-sdk/config';
import {
    SourceAMB,
    SourceAMB__factory,
    TelepathyRouter__factory,
    TelepathyRouter
} from '@succinctlabs/telepathy-sdk/contracts';
import { FunctionsClient } from '@succinctlabs/telepathy-sdk/functions';
import { IntegrationClient } from '@succinctlabs/telepathy-sdk/integration';
import { Logger } from '@succinctlabs/telepathy-sdk/integration';
import axios, { AxiosInstance } from 'axios';
import { BigNumber, ContractFactory } from 'ethers';
import ethers from 'ethers';

import { Trie } from '@ethereumjs/trie';
import { AxiosInstance } from 'axios';
import { keccak256 } from 'ethereum-cryptography/keccak';
import ethers from 'ethers';
import { RLP } from 'ethers/lib/utils';
import { fromHexString, toHexString } from '@chainsafe/ssz';

console.log('Loading Telepathy.json...');
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const TelepathyJsonFile = fs.readFileSync(
    path.resolve(__dirname, '../../out/TelepathyRouter.sol/TelepathyRouter.json')
);
const telepathyJson = JSON.parse(TelepathyJsonFile.toString());
console.log('Done loading TelepathyRouter.json');

// TODO move to a utils file in SDK

function stringFormatForForge(str: string | number, type = 'bytes') {
    if (type == 'bytes') {
        if (typeof str == 'number') {
            throw new Error(
                `stringFormatForForge: trying to format a number as bytes but we only support strings: ${str}`
            );
        }
        if (str.startsWith('0x')) {
            return `hex"${str.slice(2)}"`;
        } else {
            throw new Error(
                `stringFormatForForge: trying to format a string as bytes but it does not start with 0x: ${str}`
            );
        }
    } else if (type == 'bytes32') {
        if (typeof str == 'number') {
            throw new Error(
                `stringFormatForForge: trying to format a number as bytes32 but we only support strings: ${str}`
            );
        }
        if (str.startsWith('0x')) {
            return str;
        } else {
            throw new Error(
                `stringFormatForForge: trying to format a string as bytes32 but it does not start with 0x: ${str}`
            );
        }
    } else if (type.startsWith('uint')) {
        return str;
    } else {
        throw new Error(`stringFormatForForge: unsupported type: ${type}: ${str}`);
    }
}

function formatArrayForForge(name: string, arr: string[], type = 'bytes') {
    console.log(`${type}[] memory ${name} = new ${type}[](${arr.length});`);
    for (let i = 0; i < arr.length; i++) {
        console.log(`${name}[${i}] = ${stringFormatForForge(arr[i], type)};`);
    }
}

function formatVarForForge(name: string, value: string | number, type = 'bytes') {
    if (type == 'bytes') {
        console.log(`${type} memory ${name} = ${stringFormatForForge(value, type)};`);
    } else if (type == 'bytes32' || type.startsWith('uint')) {
        console.log(`${type} ${name} = ${stringFormatForForge(value, type)};`);
    }
}

// Should deploy a new SourceAMB, or use an existing one?
const DEPLOY = false;

// Should use a storage proof (via 'sendViaStorage') or the event proof (via 'send')?
const USE_STORAGE = false;

// Should send a new message, or just generate a proof for the old one?
const SEND_MESSAGE = false;

// If SEND_MESSAGE is false, this is the block number of the message to generate a proof for
// 8526783 - previous `sendViaStorage` block (storage proof)
// 8549692 - previous 'send' block (event proof)
let SENT_MESSAGE_BLOCK = 8550413;

// If using receipt proof, this configures how far back the historical state is
enum SlotType {
    Latest,
    SameSlot,
    CloseSlot
}
const SLOT_TYPE: SlotType = SlotType.CloseSlot;

// This script generates a single fixture proof, type depending on
// if the above is configured for storage or event proof.

// To run, do:
//   yarn tsx generateFixtures.ts

async function main() {
    console.log('Running main');
    // We're going to deploy the SourceAMB to a testnet
    // Then we'll send a message to the SourceAMB, get a MPT proof from the SourceAMB using the
    // consensus client
    const configName = 'goerli';
    const config = new ConfigManager(`../toml/alpha/${configName}.toml`, true);
    const integrationClient = new IntegrationClient();
    const logger = integrationClient.logger;
    const consensusClient = new ConsensusClient(config.consensusRpc(ChainId.Goerli));
    consensusClient.logger = logger;
    const executionClient = axios.create({
        baseURL: config.rpc(ChainId.Goerli),
        responseType: 'json',
        headers: { 'Content-Type': 'application/json' }
    });
    const functionsClient = new FunctionsClient(config.functionsRpc());
    const provider = new ethers.providers.JsonRpcProvider(config.rpc(ChainId.Goerli));
    const signer = new ethers.Wallet(config.privateKey(), provider);

    let sourceAMB;
    let SOURCE_AMB_ADDRESS = '0x43f0222552e8114ad8F224DEA89976d3bf41659D';
    if (DEPLOY) {
        console.log('Deploying SourceAMB...');
        const telepathyFactory = await ContractFactory.fromSolidity(telepathyJson, signer);
        sourceAMB = (await telepathyFactory.deploy()) as TelepathyRouter;
        console.log(telepathyFactory);
        console.log('SourceAMB deployed to', sourceAMB.address);
        console.log('SourceAMB deploy transaction', sourceAMB.deployTransaction.hash);
        SOURCE_AMB_ADDRESS = sourceAMB.address;
        const initTx = await sourceAMB.initialize([], [], [], signer.address, signer.address, true);
        const initReceipt = await initTx.wait();
        console.log('SourceAMB initialized at block', initReceipt.blockNumber);
    } else {
        console.log('Connecting to already deployed SourceAMB at address', SOURCE_AMB_ADDRESS);
        sourceAMB = TelepathyRouter__factory.connect(SOURCE_AMB_ADDRESS, signer) as TelepathyRouter;
    }

    if (SEND_MESSAGE) {
        console.log('Sending message to SourceAMB...');
        const data = ethers.utils.defaultAbiCoder.encode(
            ['address', 'uint256'],
            [ethers.constants.AddressZero, BigNumber.from(ChainId.Gnosis)]
        );

        let tx;
        if (USE_STORAGE) {
            tx = await sourceAMB['sendViaStorage(uint32,address,bytes)'](
                BigNumber.from(ChainId.Gnosis),
                ethers.constants.AddressZero,
                data
            );
        } else {
            tx = await sourceAMB['send(uint32,address,bytes)'](
                BigNumber.from(ChainId.Gnosis),
                ethers.constants.AddressZero,
                data
            );
        }
        const receipt = await tx.wait();

        console.log('Message sent to SourceAMB at block', receipt.blockNumber);
        SENT_MESSAGE_BLOCK = receipt.blockNumber;
    } else {
        console.log('Using already sent message at block', SENT_MESSAGE_BLOCK);
    }

    const sentMessageEventList = await sourceAMB.queryFilter(
        sourceAMB.filters.SentMessage(),
        SENT_MESSAGE_BLOCK,
        SENT_MESSAGE_BLOCK
    );
    console.assert(
        sentMessageEventList.length === 1,
        `Expected 1 SentMessage event but got ${sentMessageEventList.length}`
    );
    const sentMessageEvent = sentMessageEventList[0];
    console.log(sentMessageEvent);

    if (USE_STORAGE) {
        const { message, accountProof, storageProof } = await getExecuteByStorageTx(
            {
                argNonce: sentMessageEvent.args.nonce.toBigInt(),
                contractAddress: SOURCE_AMB_ADDRESS,
                argMessageRoot: sentMessageEvent.args.msgHash,
                argMessage: sentMessageEvent.args.message
            },
            SENT_MESSAGE_BLOCK, // The target *block*, the storage proof is against this quantity
            executionClient,
            logger
        );

        const storageSlot = getStorageSlotFromNonce(sentMessageEvent.args.nonce.toBigInt());
        const blockStateRoot = await getBlockStateRoot(SENT_MESSAGE_BLOCK, executionClient);

        console.log('executionBlockNumber:', SENT_MESSAGE_BLOCK);
        console.log('executionStateRoot:', blockStateRoot);
        console.log('storageSlot:', storageSlot); // We only need this if we're unit testing our state proof library

        console.log('');
        formatVarForForge('message', message);
        console.log('');
        formatArrayForForge('accountProof', accountProof);
        console.log('');
        formatArrayForForge('storageProof', storageProof);
        console.log('');

        const trie = new Trie();
        const addressHash = keccak256(fromHexString(SOURCE_AMB_ADDRESS));
        const accountStorage = await trie.verifyProof(
            Buffer.from(fromHexString(blockStateRoot)),
            Buffer.from(addressHash),
            accountProof.map((x) => Buffer.from(fromHexString(x)))
        );
        if (!accountStorage) {
            throw Error('Could not verify account proof');
        }
        const decoded = RLP.decode(toHexString(accountStorage));
        if (decoded.length !== 4) {
            throw Error('Decoded account storage is null');
        }
        const storageRoot = decoded[2];

        const fixtureJSON: any = {
            contractAddress: SOURCE_AMB_ADDRESS,
            proof: accountProof.map((x) => x.slice(2)),
            stateRootHash: blockStateRoot,
            storageRoot: storageRoot
        };
        const fixture = JSON.stringify(fixtureJSON, null, 4);
        const file = path.resolve(
            __dirname,
            '../../test/libraries/fixtures/storageProof' +
                sentMessageEvent.args.nonce.toString() +
                '.json'
        );
        fs.writeFileSync(file, fixture, 'utf8');
        console.log('generated storage proof fixture at ' + file);
    } else {
        // Using receipts

        let sourceSlot;
        let consensusBlockHeader;

        if ((SLOT_TYPE as SlotType) == SlotType.Latest) {
            consensusBlockHeader = await consensusClient.getHeader('head');
            sourceSlot = consensusBlockHeader.slot;
        } else if ((SLOT_TYPE as SlotType) == SlotType.SameSlot) {
            sourceSlot = await functionsClient.blockToSlot(
                ChainId.Goerli,
                sentMessageEvent.blockNumber
            );
            consensusBlockHeader = await consensusClient.getHeader(sourceSlot);
        } else if ((SLOT_TYPE as SlotType) == SlotType.CloseSlot) {
            sourceSlot = await functionsClient.blockToSlot(
                ChainId.Goerli,
                sentMessageEvent.blockNumber
            );
            // sourceSlot += 8193;
            sourceSlot += 200;
            consensusBlockHeader = await consensusClient.getHeader(sourceSlot);
        } else {
            throw new Error('Invalid slot type');
        }

        const headerRoot = toHexString(
            ssz.phase0.BeaconBlockHeader.hashTreeRoot(consensusBlockHeader)
        );

        const sentMessageFields = {
            argNonce: sentMessageEvent.args.nonce.toBigInt(),
            contractAddress: SOURCE_AMB_ADDRESS,
            argMessageRoot: sentMessageEvent.args.msgHash,
            argMessage: sentMessageEvent.args.message,
            txHash: sentMessageEvent.transactionHash,
            txBlockNumber: sentMessageEvent.blockNumber
        };
        const {
            srcSlot,
            txSlotNumber,
            message,
            receiptsRootProof,
            receiptsRoot,
            receiptProof,
            // txIndex, // TODO: this isn't used commenting out for now
            rlpEncodedTxIndex,
            logIndex
        } = await getExecuteByReceiptTx(
            ChainId.Goerli,
            sentMessageFields,
            sourceSlot,
            executionClient,
            consensusClient,
            functionsClient,
            logger
        );
        const abiCoder = new ethers.utils.AbiCoder();
        const srcSlotTxSlotPack = abiCoder.encode(['uint64', 'uint64'], [srcSlot, txSlotNumber]);

        console.log('source slot:', sourceSlot);
        console.log('header root', headerRoot);

        console.log('');
        formatVarForForge('srcSlotTxSlotPack', srcSlotTxSlotPack);
        console.log('');
        formatVarForForge('message', message);
        console.log('');
        formatArrayForForge('receiptsRootProof', receiptsRootProof, 'bytes32');
        console.log('');
        formatVarForForge('receiptsRoot', receiptsRoot);
        console.log('');
        formatArrayForForge('receiptsProof', receiptProof);
        console.log('');
        formatVarForForge('rlpEncodedTxIndex', rlpEncodedTxIndex);
        console.log('');
        formatVarForForge('logIndex', logIndex, 'uint256');

        const struct = {
            SOURCE_CHAIN: ChainId.Goerli,
            DEST_CHAIN: ChainId.Gnosis,
            sourceAMBAddress: SOURCE_AMB_ADDRESS,
            sourceMessageSender: config.publicKey(),
            srcSlotTxSlotPack: srcSlotTxSlotPack,
            message: message,
            receiptsRootProof: receiptsRootProof,
            receiptsRoot: receiptsRoot,
            receiptProof: receiptProof,
            txIndexRLPEncoded: rlpEncodedTxIndex,
            logIndex: logIndex,
            sourceSlot: sourceSlot,
            headerRoot: headerRoot
        };

        console.log('');
        console.log(JSON.stringify(struct));

        const fixtureJSON: any = {
            claimedEmitter: SOURCE_AMB_ADDRESS,
            key: rlpEncodedTxIndex.slice(2),
            logIndex: logIndex,
            messageRoot: sentMessageEvent.args.msgHash,
            proof: receiptProof.map((x) => x.slice(2)),
            receiptsRoot: receiptsRoot
        };

        const fixture = JSON.stringify(fixtureJSON, null, 4);
        const file = path.resolve(
            __dirname,
            '../../test/libraries/fixtures/eventProof' +
                sentMessageEvent.args.nonce.toString() +
                '.json'
        );
        fs.writeFileSync(file, fixture, 'utf8');
        console.log('generated event proof fixture at ' + file);
    }
}

main();
