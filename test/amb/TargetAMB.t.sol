pragma solidity 0.8.14;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {MessageStatus, ITelepathyHandler} from "src/amb/interfaces/ITelepathy.sol";
import {TargetAMB} from "src/amb/TargetAMB.sol";
import {SSZ} from "src/libraries/SimpleSerialize.sol";

import {LightClientMock} from "./LightClientMock.sol";

contract SimpleHandler is ITelepathyHandler {
    uint16 public sourceChain;
    address public sourceAddress;
    address public targetAMB;
    uint256 public nonce;
    mapping(uint256 => bytes32) public nonceToDataHash;

    function setParams(uint16 _sourceChain, address _sourceAddress, address _targetAMB) public {
        sourceChain = _sourceChain;
        sourceAddress = _sourceAddress;
        targetAMB = _targetAMB;
    }

    function handleTelepathy(uint16 _sourceChainId, address _senderAddress, bytes memory _data)
        external
    {
        require(msg.sender == targetAMB, "Invalid sender");
        require(_sourceChainId == sourceChain, "Invalid source chain id");
        require(_senderAddress == sourceAddress, "Invalid source address");
        nonceToDataHash[nonce++] = keccak256(_data);
    }
}

struct ExecuteMessageTest {
    uint16 SOURCE_CHAIN;
    uint16 DEST_CHAIN;
    address sourceAMBAddress;
    address sourceMessageSender;
    uint64 executionBlockNumber;
    bytes32 executionStateRoot;
    bytes message;
    bytes[] accountProof;
    bytes[] storageProof;
}

contract TargetAMBTest is Test {
    LightClientMock lightClientMock;
    TargetAMB targetAMB;
    SimpleHandler simpleHandler;

    function setUp() public {
        lightClientMock = new LightClientMock();
    }

    function getDefaultExecuteMessageParams() internal pure returns (ExecuteMessageTest memory) {
        // This test is generated using `cli/src/generateTest.ts`
        // We use the sourceAMBAddress as `SOURCE_AMB_ADDRESS` and executionBlockNumber as the `SENT_MESSAGE_BLOCK`
        uint16 SOURCE_CHAIN = 5;
        uint16 DEST_CHAIN = 100;

        address sourceAMBAddress = 0xd6d361a632b2f52F9d630f13d5ff39D6b68Ea948;
        address sourceMessageSender = address(0xe2B19845Fe2B7Bb353f377d12dD51af012fbba20);

        uint64 executionBlockNumber = 8358273;
        bytes32 executionStateRoot =
            bytes32(0x30ab020bab177e03398b58f507e5799a5b6b61fe719682a78cd71302bd9103a2);

        bytes memory message =
            hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000005000000000000000000000000e2b19845fe2b7bb353f377d12dd51af012fbba200000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064";

        bytes[] memory accountProof = new bytes[](8);
        accountProof[0] =
            hex"f90211a0331077cc7be00d7693a681cd90b24addf1bfa42877d8ed00b47f98c7b73bf827a0acab54510b95c222b3020adfc2a819af5567093a2874306a06aa2ef658392a88a0eaaba2af728eff080f160c3b728578bc1900932b763e2dc17ae231d051b82341a0cde6a4f5e29d0b41469064e0d605ff25e3921287379bcafee9739f0f907b885da0c5373a77f0c6be1fe26e7e040ee6f1fd9804fc21908c2d42af227cd78513ebc5a0b00bac8fefa41d57c6088869f5d6aff6fabdf5f8f3a6383be379ba7a3a31a4b8a03708802fa8123f98020a337abcb92eb6cf4696b0b4e64fc05540c314d2676332a04f7b16f99258d03b391d3a89520caf40224b185f9d8c18ab5a26956a8b73535ea09f86bd43e721e0814e5c07843fc125ff87ae58145ad41e64e8c2f16ed5ff3b54a0e7fcaf232f641f99db409a49476305a544b101606d1e55f6fd3652dc5b6a29aea01bfe2493b309905d0bf1554e93d0a7d39d63f95b1a4585b476e8b9cbafbe7691a0875f05b8c2b35d78d4bada324b6abb6a0b76d9efbb7e4f58b6b62395d6a56171a06173bdbb36a67061c4f92ef919c7b9fde2204b465c83f5440465c4b74dbeb5f2a090066a341367612ad29de1689551aec66cd5d3629cef12bfc25af5d560869e1ba0f4c939622ae19d233170faf5ff41ea9e10d8b15c37efc111868e0bec96904267a0b0625880c1d48adfd02da62ce0f6dc451542507ccbc6abafae2c17df03834a2080";
        accountProof[1] =
            hex"f90211a0b6aeca06d330ab39cb35d32b1654c3d5ace577e66d7bc699b360eda061ab93f0a068126e78c5b327db4bd65ecf9248621408da2c73203e4e953c959cae8a63b059a08469e3cccfdbf48ba683b14fb66083fbb03c72d47a73e37ea342cd743a05c827a07b107b24003babe5ba664961ffc90f8d46bc690a5fbb22f8ce1d6d455829a428a06f933aff05a262b1162bc471c367ba5c029e379f5eed97ebeaeb06af1e3b78e2a0eecfe0fdb7263f194f586d1b13363b8a170d9c931db7c08d4ee682e334a6b31ba02f72be3a0d7c1f19ff00e4a8b50e50410796598e5004c8ff144ba04e93c0a37fa0c3fb818c32647a6fefefe12e54338d8d9cb5993acdb22386d5636a47efa028a0a0ad0529d2d7f54c93b0751c991433e555c0a289ce316462d50119b0a5b9ad7359a0efe333b33cde573d749484a76ea92d08f051b53d0447fb10b56a2648a12330dca07937fcab43555fb84c4cbede086ed8605ce86a51b6c76ba50cfa82db4788e054a0cc1bbd790116ce23ae73b473778e1aae7796cb2efaeae9748c09859838dcb6c8a07910702c68cb97fb5e3421a3da88958c63cfe9f548a60c070d59588c0086c3c8a0967ab3c6cfcdfa87afc0235b665c2f6d836ed269e184b3811b432f717d99971fa01298e1f0f0e8e0d6398734b00a6d9f192c7e8d041f5d7870793360950f596d19a0144762f25b9e78dde8cd9ba7a5fde1ceaa3d05d49ca793c1f74728f93b3e4cd980";
        accountProof[2] =
            hex"f90211a06597a8319549b460d15635f58c86c5b1c270a638e53e67e8fcd0e190481b79dca0e31a47d83d01414122224088a3f2c78b7b7daeb810d1f4e73a8a91eac5e45002a0f20eca4dd57aafd848340820e8857f70681587791876049cb2b717d2cee1c85ba05da7848907eba0df27013bb88d3cb4db05badd6dd8d01f4bd6d9c52d45494b4ba0b1f895c3439528c1c4f7bb892f4af44a8be445ae28d9859fc85d1f38947daf52a0d675eeb5a6d5958264e7efc451876bdbcb34554e724a5c69a93ed1556ca3c0e8a0afde6d1da073fcea1906c2f67a346def114aa52eb710f66c5d9eb7a0832eb959a0bc298696f7d69e6a26f8c0910b238d12123a5bb089858c7eff6148692ee3bdf2a08fa7175a93d9b68c24f653a662343fbc47bd65233ff9526a4bab72877105e03da02aba14a886693d8a0d7e61b1c410357daead40434e109684395f9c1acf1e4abba04949a9658a79ddb84a4d078b7f4302183c8a4d36263127ffe616123db81aaaa0a01248d22eed83bb10643c8eac9077b60c7ba42c11b0b2141cc6204b9647e8661ea0a2a07f60ed60ff607a60a5468470c551ba69652adc4ec93b8764d9fbb2ec463da0f12c23f31f9c6d6e7a36fb4e604964d44877e55c097319d9d910d08dfbfe464ca011860d9c08ce9f5b9bc79df9d11edfe5b97e511d8d899fdba5160ee17c168b7ea086c144f0b1de7447a94fe0c5ab771d57947dd7e3beb3d08bfdb1b80d3da6b9ac80";
        accountProof[3] =
            hex"f90211a03caf5ea5ad4f19384abb1e940a1174afdcb63631f8281fd90dc0d34d8736385fa0d5bbf7a9a4fea199bac2ffcf160922d682751ed2e3ff33e6ebb14b301df913a4a0a5fc8e4c63adced52a725c1dfb78fcc70d4436f5f3972ff095220e41087ac907a096c70e2b43dd0ecab6168baf2f8967268e8ba446feac3799cb265ed0d7262c0fa0e337949d84a7fec7b5950cc559ceed127b69ff43b299e2521fdb0772ba55179aa0f85b846d4f4475c3e992dd2cb2611b4dbdaeb3e941fb3d7ba35d0d394bbb276ca0de1181d03cb33056cc2cfd5ff0ac033b813e459ce133e85258f6b17a13924ac8a0d495a4c80817886a46aa51e23025f341ec092457621cbad4f8cb5ee00899fa65a08eb3db8834b199178ba544761c2fcb3203137d6559ca8727329cc110b8780c7ba0767db3ffc4b2e0f741f29630816bb47e063ab63d21be72dbf51e16517f8cab0da069f24f5007091ec8bd619d9abdce96643ad02632080f0212f2235e5e2e0a8cb2a04fda17ea9931ed81b031012a0cae464625e73ea886a5cfaab91ddd8fd14f88a3a0b4b95901d98f89eea959f0f727141edbf9ec5a729ed12d34b391a670b8b9b34aa08d9177b29852f8cac69f3bc228f59d3290ef81e9f27e7b3b4492d138a954edb5a0be9a4b4666a8f5bdfc3cab7f91ab2ae1d4f382720f8f7cafffd774022e567008a0164fdbf92f61d735eddbd949a200070fe3466cbafe280b237b424a02848d2f9280";
        accountProof[4] =
            hex"f90211a0f90d36755b05911d4cd4c4547efea7500f74d2b5dd4a8cd8d560b9ec40b75e60a0c50952961915e08a9de9b065d3a6ab40f5faf2ffb05f17ae468c33ebaf434610a00f319e18bd886ffa575fb8b27c274ae4c5434f70e98011ff39dafb211bdb7bf8a0fb8e7a84494caac40fe2558fb2be64726bea9a930a82c4e27bd667d3cc2c9ee6a077f81a60b6e6c467bef038233422e2506268140e9ca07104b4d1346046aac434a0a18874d51a58eb362cc639d5f8e852f8993abfa4816220af7e7be7627b7d76bba0ae05fc97227c4e6ed4c8a73850c0626648843b93647dbf50c114920a1e29b086a07a91d78b352b1cdb5f74e5c2750d6afe3ab554b24de49408ed1589123b6dab19a0162d51cd3766bed212e0473b0141a6f874adb7ccdae483dc2d980340d762d6f5a04d419281fc2da21091c1c51fd91f55eb3f668f7d1af884dd5d73513d6ff1dc9aa069dc1d842f1a8b8255143d3165f5964f2c3d400a7d07960542d437e9b532f86ba0e4428f0477eabf15ddd31902a8951fbe5d5911f70f7c5c7032350b1d6e2c53aca0fdc5301970a23cf5eeeb19ebc9df6a586ae33ed89aa80a7e2386bf152ad9f163a04e630f0c6efde7b958e92e7f5fd72202dfc67e3a7ea8482cf42174ea83e698bca0fb33568fc28d42c0ca9ceba484f4eed9fba554c1f201f373f2cd4890f2af5717a06caf4c2e581c10145d4bd98da0f5aa749f302dfdcfdea3d0dcdaa9b6707a5c1a80";
        accountProof[5] =
            hex"f90111a03f6e42f83b59add750f42fa6633158f727ceab3aa45625eb40cebc69051acc16a064e29db5899c8479127e0c7b4a679a1b69273c29efffcd26e826880110cc2b748080a036a14dbfb0d204e0612a5456efa1f630f8a0d09c0a7ec2ed789a8c8cd1210dfca0b12fcac5a4861e39d289177840aff4865004c2cb1879a02830470dea4742f782a070c2f9a271bc31c302ef1e568317cefe4b33fb0ddb99bf260d272defc61eebdf80808080a07c8debcef7db53bb8534ef91604a9de4faeee977e62ae10223bb11926fadd523a004f522aa3f2ed255b4f5e33922668a5a08a2e80aba68755a5cc4ee84e788722580a04ecb1abf4954e07fbb69bfb395fdbf5b148312b9e95be8ee4c5950a49ba2b4278080";
        accountProof[6] =
            hex"f85180a0810a7767315b5bc38a55f584bc168817488a7ab05a626129f8e6832b619acc3980808080a0209473695ce1083be17e731c9d9f08601bc64f6905b855752211296bf6da916180808080808080808080";
        accountProof[7] =
            hex"f8669d38e0da5e0953fa3d4b1a73b3210f61035d791b940f779926c63824171db846f8440180a0de22fff41d2316e3e33137005c6133e234075ecd4d875e289b940183c39bbb7fa0b0d68312b98a2f06ff2ebe4b56e835ba817786fff7c0fa5ea29d37952cb7798d";

        bytes[] memory storageProof = new bytes[](2);
        storageProof[0] =
            hex"f851808080a07cd2b195c2229fc66e5e7eebcccc07b853782c8b93bf065ea24c1abd8f69d2a180808080808080a0236e8f61ecde6abfebc6c529441f782f62469d8a2cc47b7aace2c136bd3b1ff08080808080";
        storageProof[1] =
            hex"f843a03f9553dc324cd1fd24b54243720c42e18e5c20165bc5e523e42b440a8654abd1a1a0ff60cd3d606351ed8e487db5632e370c30105ec6b33441d76b95029d7036c156";

        return ExecuteMessageTest(
            SOURCE_CHAIN,
            DEST_CHAIN,
            sourceAMBAddress,
            sourceMessageSender,
            executionBlockNumber,
            executionStateRoot,
            message,
            accountProof,
            storageProof
        );
    }

    function getDefaultContractSetup(ExecuteMessageTest memory testParams) internal {
        vm.chainId(testParams.DEST_CHAIN);

        // First initialize the TargetAMB using the deployed SourceAMB
        targetAMB = new TargetAMB(address(lightClientMock), testParams.sourceAMBAddress);

        // Then initialize the contract that will be called by the TargetAMB
        SimpleHandler simpleHandlerTemplate = new SimpleHandler();
        vm.etch(address(0), address(simpleHandlerTemplate).code);
        simpleHandler = SimpleHandler(address(0));
        simpleHandler.setParams(
            testParams.SOURCE_CHAIN, testParams.sourceMessageSender, address(targetAMB)
        );

        // Then set the execution root in the LightClientMock
        // Typically we should use the slot here, but we just use the block number since it doesn't
        // matter in the LightClientMock
        lightClientMock.setExecutionRoot(
            testParams.executionBlockNumber, testParams.executionStateRoot
        );
    }

    function testExecuteMessage() public {
        // This test is generated using `cli/src/generateTest.ts`
        ExecuteMessageTest memory testParams = getDefaultExecuteMessageParams();
        getDefaultContractSetup(testParams);

        // Finally, execute the message and check that it succeeded
        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            testParams.accountProof,
            testParams.storageProof
        );
        bytes32 messageRoot = keccak256(testParams.message);
        require(
            targetAMB.messageStatus(messageRoot) == MessageStatus.EXECUTION_SUCCEEDED,
            "Message status is not success"
        );

        // Check that the simpleHandler processed the message correctly
        require(simpleHandler.nonce() == 1, "Nonce is not 1");
        bytes32 expectedDataHash = keccak256(abi.encode(address(0), uint256(100)));
        require(
            simpleHandler.nonceToDataHash(0) == expectedDataHash,
            "Data hash not set as expected in SimpleHandler"
        );
    }

    function testExecuteMessageOnlyOnce() public {
        // Tests that a message can only be executed once.
        ExecuteMessageTest memory testParams = getDefaultExecuteMessageParams();
        getDefaultContractSetup(testParams);

        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            testParams.accountProof,
            testParams.storageProof
        );
        bytes32 messageRoot = keccak256(testParams.message);
        require(
            targetAMB.messageStatus(messageRoot) == MessageStatus.EXECUTION_SUCCEEDED,
            "Message status is not success"
        );

        vm.expectRevert("Message already executed.");
        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            testParams.accountProof,
            testParams.storageProof
        );
    }

    function testExecuteMessageWrongSourceAMBAddressFails() public {
        ExecuteMessageTest memory testParams = getDefaultExecuteMessageParams();
        testParams.sourceAMBAddress = address(0x1234); // Set the sourceAMBAddress to something incorrect
        getDefaultContractSetup(testParams);

        vm.expectRevert();
        // The MPT verification should fail since the SourceAMB address provided is different than the one in the account proof
        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            testParams.accountProof,
            testParams.storageProof
        );
    }

    function testExecuteMessageInvalidRecipientFails() public {
        // Test what happens when the recipient address doesn't implement the ITelepathyHandler
        ExecuteMessageTest memory testParams = getDefaultExecuteMessageParams();
        getDefaultContractSetup(testParams);

        // Set the simpleHandler code to random bytes
        bytes memory randomCode = hex"1234";
        vm.etch(address(0), randomCode);

        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            testParams.accountProof,
            testParams.storageProof
        );
        // The message execution should fail
        bytes32 messageRoot = keccak256(testParams.message);
        require(
            targetAMB.messageStatus(messageRoot) == MessageStatus.EXECUTION_FAILED,
            "Message status is not failed"
        );
    }

    function testExecutionMessageInvalidProofFails(bytes[] memory randomProof) public {
        // We fuzz test what happens when we provide invalid proofs.
        // We fuzz test what happens when we provide invalid messages.
        ExecuteMessageTest memory testParams = getDefaultExecuteMessageParams();
        getDefaultContractSetup(testParams);

        vm.expectRevert();
        // Finally, execute the message and check that it failed
        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            randomProof,
            testParams.storageProof
        );

        vm.expectRevert();
        // Finally, execute the message and check that it failed
        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            testParams.accountProof,
            randomProof
        );
    }

    function testExecuteMessageInvalidMessageFails(bytes memory message) public {
        // We fuzz test what happens when we provide invalid messages.
        ExecuteMessageTest memory testParams = getDefaultExecuteMessageParams();
        getDefaultContractSetup(testParams);

        vm.expectRevert();
        // Finally, execute the message and check that it failed
        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            message,
            testParams.accountProof,
            testParams.storageProof
        );
    }

    function testExecuteMessageWrongSrcChainFails() public {
        ExecuteMessageTest memory testParams = getDefaultExecuteMessageParams();
        testParams.SOURCE_CHAIN = 6; // Set the source chain to something other than 5
        getDefaultContractSetup(testParams);

        // Finally, execute the message and check that it failed
        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            testParams.accountProof,
            testParams.storageProof
        );
        bytes32 messageRoot = keccak256(testParams.message);
        require(
            targetAMB.messageStatus(messageRoot) == MessageStatus.EXECUTION_FAILED,
            "Message status is not success"
        );

        require(
            simpleHandler.nonce() == 0,
            "simpleHandler should have nonce 0 since execution should have failed"
        );
    }

    function testExecuteMessageWrongSenderAddressFails() public {
        ExecuteMessageTest memory testParams = getDefaultExecuteMessageParams();
        testParams.sourceMessageSender = address(0x1234); // Set the source sender address to something random
        getDefaultContractSetup(testParams);

        // Finally, execute the message and check that it failed
        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            testParams.accountProof,
            testParams.storageProof
        );
        bytes32 messageRoot = keccak256(testParams.message);
        require(
            targetAMB.messageStatus(messageRoot) == MessageStatus.EXECUTION_FAILED,
            "Message status is not success"
        );

        require(
            simpleHandler.nonce() == 0,
            "simpleHandler should have nonce 0 since execution should have failed"
        );
    }

    function testExecuteMessageWrongTargetAMBFails() public {
        ExecuteMessageTest memory testParams = getDefaultExecuteMessageParams();
        getDefaultContractSetup(testParams);

        address randomTargetAMB = address(0x1234);
        simpleHandler.setParams(
            simpleHandler.sourceChain(), simpleHandler.sourceAddress(), randomTargetAMB
        );

        // Finally, execute the message and check that it failed
        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            testParams.accountProof,
            testParams.storageProof
        );
        bytes32 messageRoot = keccak256(testParams.message);
        require(
            targetAMB.messageStatus(messageRoot) == MessageStatus.EXECUTION_FAILED,
            "Message status is not success"
        );

        require(
            simpleHandler.nonce() == 0,
            "simpleHandler should have nonce 0 since execution should have failed"
        );
    }
}
