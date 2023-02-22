pragma solidity 0.8.16;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {MessageStatus, ITelepathyHandler} from "src/amb/interfaces/ITelepathy.sol";
import {TelepathyRouter} from "src/amb/TelepathyRouter.sol";
import {UUPSProxy} from "src/libraries/Proxy.sol";
import {SSZ} from "src/libraries/SimpleSerialize.sol";
import {LightClientMock} from "./LightClientMock.sol";

contract SimpleHandler is ITelepathyHandler {
    uint32 public sourceChain;
    address public sourceAddress;
    address public targetAMB;
    uint256 public nonce;
    mapping(uint256 => bytes32) public nonceToDataHash;

    function setParams(uint32 _sourceChain, address _sourceAddress, address _targetAMB) public {
        sourceChain = _sourceChain;
        sourceAddress = _sourceAddress;
        targetAMB = _targetAMB;
    }

    function handleTelepathy(uint32 _sourceChainId, address _senderAddress, bytes memory _data)
        external
        override
        returns (bytes4)
    {
        require(msg.sender == targetAMB, "Only Telepathy can call this function");
        require(_sourceChainId == sourceChain, "Invalid source chain id");
        require(_senderAddress == sourceAddress, "Invalid source address");
        nonceToDataHash[nonce++] = keccak256(_data);
        return ITelepathyHandler.handleTelepathy.selector;
    }
}

library WrappedInitialize {
    function init(
        address targetAMB,
        uint32 sourceChainId,
        address lightClient,
        address broadcaster,
        address timelock,
        address guardian
    ) internal {
        uint32[] memory sourceChainIds = new uint32[](1);
        sourceChainIds[0] = sourceChainId;
        address[] memory lightClients = new address[](1);
        lightClients[0] = lightClient;
        address[] memory broadcasters = new address[](1);
        broadcasters[0] = broadcaster;
        TelepathyRouter(targetAMB).initialize(
            sourceChainIds, lightClients, broadcasters, timelock, guardian, true
        );
    }
}

struct ExecuteMessageTest {
    uint32 SOURCE_CHAIN;
    uint32 DEST_CHAIN;
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
    TelepathyRouter targetAMB;
    SimpleHandler simpleHandler;

    function setUp() public {
        lightClientMock = new LightClientMock();
    }

    function getDefaultExecuteMessageParams() internal pure returns (ExecuteMessageTest memory) {
        // This test is generated using `cli/src/generateTest.ts`
        // We use the sourceAMBAddress as `SOURCE_AMB_ADDRESS` and executionBlockNumber as the `SENT_MESSAGE_BLOCK`
        uint32 SOURCE_CHAIN = 5;
        uint32 DEST_CHAIN = 100;

        address sourceAMBAddress = 0x43f0222552e8114ad8F224DEA89976d3bf41659D;
        address sourceMessageSender = address(0xe2B19845Fe2B7Bb353f377d12dD51af012fbba20);

        uint64 executionBlockNumber = 8526783;
        bytes32 executionStateRoot =
            bytes32(0xc1140c46ee3f27852d73ef38c8675e51fb7894ad161c17ec80b40ed650e9fd84);

        bytes memory message =
            hex"01000000000000000100000005e2b19845fe2b7bb353f377d12dd51af012fbba2000000064000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000064";

        bytes[] memory accountProof = new bytes[](8);
        accountProof[0] =
            hex"f90211a03bd19a6c1742200cf6628ddbd84c16447dc2c272975ff4552b5771d4e6dedfada05e746bd03824f02b49da325d47e7cd45eb9687f4de20b5d693bcc92ce32fc868a0e6c1263505535010c111f9499896930fda2afebd2d10adf04f202eb32f50da85a0c9ed8eb608b02ba64f0ddedbd756aa036a8fbe21bf278b75a5b21946fc100513a09ef0f2395db0bcf2c88ab9d421145ec3c6bdc9f6c111a4db3916ea18b0b6936da03328cda49a518c506247b34a6e1bdd95b6b774c0ea59c9816b2bc4d0f76b1d00a0324d9c31bc11704c364375a7737d33caa2ed8cc4523e8cc3b2b8251e9f4eff79a04a3af2b35a308f04e8ea02804add88fd913aa208705857f7a72af65128f0038ba0addbe8ef55caa89582abf06b2e4e16a5e7fa8153cb4a1519257867d03a0820bda0d366e52e66e5a009886042c41362057fd632e51126eda0f7c9ade01cf8886809a0ecf3c10887272883d2423c1c599c179c5355c660450eafdc1b5ac9a050a79ef4a05a02573a5fe2733adbc978ca1ad3688d17bd96f3d445f1210827c039a2b525a2a0b70e66dddb52517c3b59eac52003d8c6b6b18b29102d21efe2cb74f76d5a0ef3a00b203210824b59de079f7cf03e4816f19ffcc12f70fe25b3140ebb7ce0affc16a0cd234830927880346e9203e7786d16fe856b5e9662dd69b7726ab8ad212ba2daa0ac8f1fda09cbfbcb021d5e36e9f5f515ac469d376516f779dce66bc5b078b62e80";
        accountProof[1] =
            hex"f90211a0f566f3101c170993bc57400ff9d9f50a8faca2ce95132a67420ec1fb16ac6d62a02230d804c0d3f2268263126a95c1f5422dc465ba7993639d58b16009c01929f5a0c78aa7bce5629e2ebad2f2dd53d1c9aab4fbd8717f68ffcfe9d40c17be27e973a0d1bf3e29b992c3fd3b54a729990cd3eb5de594b9885f68d5ae1e8e01c9c1cb9ba0c3607bd329c6f6db1da60812aa27a4e1195f964e6ea60225903afdede6f2208fa0bb44287538e17219c8b013cb23037e019c7c7134fa38d91a7a5d64a7e32b624ba068a9697a6f499598fcfb7551470dffa9eebe8ab4ae9f0fa77b6f29f8ee61cbdfa0f7d16b7f4d18eec17b78c8985a62aa9c95648f4ddd617f58056b1ffb07d7d61ea0c6d595e1df1c4dbda89d2fac816205665bff6170e95f96f5412fff0619997a64a0c1a9d0ee06ef9476bf11415a01af3bfc439cb0958b7ab886e7674af55c97e106a02f8d4febc97cfe72c25d4f7a11f9a1046aca4ef2d16a060f89030a408a4fecfca0acc84f0beb132bd65b6abe053100ee1696629fb3ee8e22a944eed76c915cc32aa08cf851814b6d2844e2fa8bd6fced48fc74ea1861eb3a2bd4007d69525fc7896aa0162d5273047592d334b53de07c505cb0c89551a61d7c75b64da736122d77b04ea0fa3cae65a43b233350be9df882905ac5ce02aeee2ac6942b412f66485d8c5a38a0431b2fd8be6213792603171e1509aee26eda44c784207b5c382f0feba326f1b780";
        accountProof[2] =
            hex"f90211a0df6e3753f24f4805d083e14e7ee4c80853f8b8e21e3382f8ea79bd8c2cb6f6daa0b2ef9523b51ed1494c498c42fb446bbc3e36f5b77fdba9c5893ada34246cbc77a0bd2f857c9e3200678b663ac43572b620e2a67daf501055555c0a7e823098941fa05acfe9c8a90cb3a4e80c0251cfefa2fa7d4c6202eb7144bad42d988761b32a65a0c05c63c1997815307c2f2951875759e6258932530d86ab5eabfe0cde204e5f57a0a7adc0d3b705fbb5fff5f05d270ae02751aeead546e7e05915df504c4de81687a0a3c4851945e2e065aae6a4c9c52011352f9f6fd6b67d9138a3922d9c54c3b1f3a0212dc3e2343d6464870590417adfd2a1cc353f8bc4ef4ba2b693fafa386825b8a0dccb885c12b8e796e0b73e41f7759ce40914827f5d646219419678c31b5bbbc9a070b131bfe26604fab6a7a91c157a61a63a43862074beed757fa47603211099e1a0d5f6558eef1977f225d53d0ef83cb0ec25eac97097ab35f636dab004c5ba958da01222ab9ea2109d73c35fcc33034a8f9dc0d98db96b91864d75724fe118ee5b4ba0e1c4ea70c2e27d3503bb67a570fb2bf3a2c135210b41ae498aaad93a2b800e4aa02447bfe426be20ec117c4cdb132342de68b3b506cc24865ad2c77d049d4c40dda0f5e5830c34576516ab05f90d242029b811f333b6c344639816ff9580983826a0a042d6d4824d7847a0b5e771e65893bf0bafd18bd7e6407d58c39ab0b258ddc85380";
        accountProof[3] =
            hex"f90211a0237fb830ee581953b555820fdf10dece45c17bb353ca26c35567c03764a70beca09e32e1c1be1d02043db1c19642b8942d0ca9499f897fc37f2e130eb291f4d137a0b57aca7cfc62ad12cd3cc8288d299886c7b0c89387f7056b63b12d9c8b94c079a0c55793de8971a908860c8258653802d7b0526bf7dec7f95ba26aa413f751f0ada0e8fc290145bc6caf4a4baf90981d9963383f38f405e05226353d7b35d29516f8a0c7cd75ace9be8396f7678074257777fb4c57e688c0e273618f6fa3b582a249eea0c62ac4060a389509be045bab770f2009160fea98af14aa3bf39bb66b09e3259aa041c183dcc2d1054a7cb93eea6ee8b0cb0ff2be539329791fba9bcb4048ae7349a04650c05aa52eb20ac6bc71a5001d7cebc3520b7c6f3e9cf67f5ed823ef941a0ea03b23143b64450a8397160e2938ef5c766c5af056607d04304eb30678d3d25053a0a709af8f7f6155683bf08ac80431842db5bca46fc6911c0c32ed1b5c41825af0a0d69202e0a727516ab871b547a28266cfe606b83d1e65dd4f0ba7effa328ec10ca04986ad574c04704e47eb964d4a9ccccee2e431e46ca44fa65d0844e2ef3129f3a046d8aeea4fc84a0cd4ad027d764d8ee3c1058a70a5cf20b68c55f6fec90cae76a04a54d988c02e489d82911bd05f55fc34c38f73199586827cf957eeb1bab8c203a004d191346d576b7f4b4d2a1cd82263334ee94f85c485b453580893a6c5ba407880";
        accountProof[4] =
            hex"f90211a0bc80d8ae6ccac93ee4b2c020cdc98e960c2f840719e4eed518a28462f5c2e042a0483a58805884d35ba489cfe01aadaca714c73867e07844f2ef681e909bba7ca0a09819c26c70636d6d602fff3882a241f402413ce511296827f8e49be15f24e535a0a271575aa97bb6ba565c88ff126db786ed4cccdb6af8632a37e95c284b1d0224a0d73c5946469b9925e7681f45580a8d957f98a05f80a1a9bd7fe229ab79fbb7eca0d68ce50c5b63e64289821a13e13b81ad32e91fae32757ab6c3a5b6c5a675e59da0a2c63d00409e11dce2433521617080599719f65e727fb1b966d288fc5515515ba0db5123fbf15c59b047fd8004a5187e69a66bc88dcf3047a1a53c8c5e2ea2759da09d89e4cb7aaed610ffe44e3e01a34312e5a40514b4f9c40b77cfd2127cc0b841a06445d3facca17a85a1a00303be079f8d6ccda87312ca6ca9d35a1cd5b178c3cda0c158363b7c36d9abf2c07fac52c43ad8cbb3708af4c8375c64408da4b1c6112ea0a381fe5f68f97388bd03373d74d3e6d5928c6a61bea78ac5afcc4831fad2a9c7a01b3dcccc131a7d680b142444d62f3294bdab7c8e30240cbef4d898321bb72fb2a0c16af6dc08cddc53be6d58f0f2bc7e4707ed9d2ab102140930dbf136428700e2a0d68b134cb5a9433729bb46521b46e9bf737fabe2c1568185dc0d62cb2df23633a072708353bc10a239c80991deefd9a08158902b0d4ddd81857541368358e71ab280";
        accountProof[5] =
            hex"f901518080a06b3861e939ffd924c512e631febac4b7573840910a230356701f5d9876d462f78080a0644b04a89b048be9044f7ddf0ddfcfdf16eb859770c59bea283be83efc0ab852a04783d2f6f95d2df8ecfe9cd176aabf0d5ce6e1a52009c0d7d8016a9c897cd996a05ebf2e95f0ce88623be1b9df655ddff6032bb68530ce80fc060914a26c983ed6a0b2cda30c80dadf34909d937dc977928bef8b702bcf64ac7cbfb14a1c55444898a0de3bef8b9dfce8c4a2d24b6ca802f5116e7e873ea2d0863f1cf72c23672f82c280a04e75b47f705d7811a0d326440a499b2dfeb0959cd151f91b71896111bfe8ae6580a0a72d90be51e4343bc592ce8d382e141cdf6a4b7607c2ab6105d20caaf5fd18fda0cbab9ef5e83548e993c5cd9b688af2f34c6d9c5c632b59b687fa5a5e87b6bbf2a0fb82bb552d3eec458a68d01642f0e7df3d88d5b3040f69fa79b2e402adf412fa80";
        accountProof[6] =
            hex"f851808080808080808080808080a035d937961d73f8a0eea9ae41b2f4cbb73c1d2c0666ea35f1ae05c43b5896b1098080a0b7ff6c99bfa33d6709fae1d666ab99e439369ed76ee710c75027bdae6f400af280";
        accountProof[7] =
            hex"f8669d399e1ef4313dc3558aee86cc911474c2262f1dbe387aea254422552a5fb846f8440180a0687cfd5fd557d344460be5e81aa3c23e9d755bf2a7fe5f2c87b494b8d766c39da0356c7854fe7a483ece02a531c58b63aa2bdbab40df89c9f919f0d524b54dd494";

        bytes[] memory storageProof = new bytes[](2);
        storageProof[0] =
            hex"f8d18080a04fc5f13ab2f9ba0c2da88b0151ab0e7cf4d85d08cca45ccd923c6ab76323eb2880a09ddd70915eb71e1c868c88a5e19e1b60b8f7c12727c5db3829b5e38d770661aba01416f1af0011d9a9306fd51d025192d5babadf238816b12ec4118d472224b6cea05fb2784890673b9609895cc1d2276756c3d495f5b847800af9de3c9c6cf455ab80808080a02b1e1fa86147ab6fb0001f24215f7a95fe6da33c5bfb6bb85ed624b7bd41aef0808080a0d285522c440e68bab42b6193b83c3fa7d3c365f4f60ee6c9f06379d107a6bc5480";
        storageProof[1] =
            hex"f843a036b32740ad8041bcc3b909c72d7e1afe60094ec55e3cde329b4b3a28501d826ca1a0c1ad44d1b7bf34b4cb6b370b759ee9bc701644f90356010b40cfdc6b408fcefe";

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

        TelepathyRouter targetAMBImplementation = new TelepathyRouter();

        UUPSProxy proxy = new UUPSProxy(address(targetAMBImplementation), "");

        targetAMB = TelepathyRouter(address(proxy));
        WrappedInitialize.init(
            address(targetAMB),
            testParams.SOURCE_CHAIN,
            address(lightClientMock),
            testParams.sourceAMBAddress,
            address(this),
            address(this)
        );

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
        vm.warp(1675221581 - 60 * 10);
        lightClientMock.setExecutionRoot(
            testParams.executionBlockNumber, testParams.executionStateRoot
        );
        vm.warp(1675221581);
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

        vm.expectRevert();
        // Finally, execute the message and check that it failed
        targetAMB.executeMessage(
            testParams.executionBlockNumber,
            testParams.message,
            testParams.accountProof,
            testParams.storageProof
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
