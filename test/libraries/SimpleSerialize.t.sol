pragma solidity 0.8.16;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import {SSZ} from "src/libraries/SimpleSerialize.sol";

contract SSZTest is Test {
    function setUp() public {}

    function test_FinalityProof_WhenEthereum() public {
        uint256 index = 105;
        bytes32[] memory branch = new bytes32[](6);
        branch[0] = bytes32(0xe424020000000000000000000000000000000000000000000000000000000000);
        branch[1] = bytes32(0x75410a8f37f9506fb3f972cce6ece955e381e51037e432ce4ca47479c9cd9158);
        branch[2] = bytes32(0xe6af38835c0ac3c2b0d561dfaec168171d7d77c1c2e8e74ff9b1891cf43faf8d);
        branch[3] = bytes32(0x3e4fb2d12bd835bc6ee23b5ec65a43f4493e32f5ef45d46bd2c38830b17672bb);
        branch[4] = bytes32(0x880548f4df2d4003f7be2fbbde112eb46b8f756b5e33202e04863000e4383f3b);
        branch[5] = bytes32(0x88475251bcec25245a44bddd92b2c36db6c9c48bc6d91b5d0da78af3229ff783);
        bytes32 root = bytes32(0xe81a65c5c0f2a36e40b6872fcfdd62dbb67d47f3d49a6b978c0d4440341e723f);
        bytes32 leaf = bytes32(0xd85d3181f1178b07e89691aa2bfcd4d88837f011fcda3326b4ce9a68ec6d9e44);
        assertTrue(SSZ.isValidMerkleBranch(leaf, index, branch, root));
    }

    function test_FinalityProof_WhenGnosis() public {
        uint256 index = 105;
        bytes32[] memory branch = new bytes32[](6);
        branch[0] = bytes32(0x4304060000000000000000000000000000000000000000000000000000000000);
        branch[1] = bytes32(0x13d781c6071a2b891edb67074f277c7c23d36a6e64ee7686ff26c69e01cedd92);
        branch[2] = bytes32(0xdec4894b48bdfd9658bb724dfdef690c3cebefbb13cd1f4a8511963279e37673);
        branch[3] = bytes32(0x96eb26d63d5c650d76a9ee178f9f4270b025564ecddb671ac47aa50b6c97d893);
        branch[4] = bytes32(0x742273899db19d04656d63f8cb8f6c21da144d482746769ab8d4500fbb06981f);
        branch[5] = bytes32(0xcbc5ef1e4f078df1b83d9ffea0f1f112382da4bfb871e07fef353cd236b94489);
        bytes32 root = bytes32(0x93d340d3b741c02e7605b7356ba861c74ec371572d3a5a5b23bf0b6dd6823d35);
        bytes32 leaf = bytes32(0x27f156361ae4aa32fb323cb48e5bc47f84af8e25f659bb44ef8d34cb7cec349d);
        assertTrue(SSZ.isValidMerkleBranch(leaf, index, branch, root));
    }

    function test_ReceiptRootProof_WhenCloseSlots() public {
        // This tests the receipt root proof against a beacon state root.
        // This tests the case where txSlot and srcSlot are within SLOTS_PER_HISTORICAL_ROOT
        // of each other.
        // The function costs 38k gas.
        bytes32 srcSlotStateRoot =
            0x8a971d2c00794efcb266732a1fcf91ae69b78b60d97918e0ba13fe086ac0c68b;
        bytes32[] memory targetSlotStateRootBranch = new bytes32[](27);
        targetSlotStateRootBranch[0] =
            0x3c1922a5ea241463bfacfa6e4c55dc63ee235b706cbd972bd549fb5a35211443;
        targetSlotStateRootBranch[1] =
            0x58824c5477a7944fb347e955b5f160fd5b9e4578dc3869a8f2faa763bb2f280a;
        targetSlotStateRootBranch[2] =
            0xb4ef22a350546b78e23c5b4eb62612a5bbade9edd0952961766abf704f22867e;
        targetSlotStateRootBranch[3] =
            0xf461bf759330c4b87849369839057ac181d8f16056e94af94b083ec370c6bd29;
        targetSlotStateRootBranch[4] =
            0x0000000000000000000000000000000000000000000000000000000000000000;
        targetSlotStateRootBranch[5] =
            0xf5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b;
        targetSlotStateRootBranch[6] =
            0xdb56114e00fdd4c1f85c892bf35ac9a89289aaecb1ebd0a96cde606a748b5d71;
        targetSlotStateRootBranch[7] =
            0xf4ba75b3557546db48af6a65a4d9c85caae9ed1ed49a2e8e0dc8b5ee16bb6c19;
        targetSlotStateRootBranch[8] =
            0x5bc6c323360ba17bab7bc008e42f3b724fdc42a0ecaaca350f7ed9996c7bd2e7;
        targetSlotStateRootBranch[9] =
            0xb4ac9b73fea5606f0d6af8202660b0435f88ddd7546f1a4d625a72844250babf;
        targetSlotStateRootBranch[10] =
            0x268eba359db6b7a392ef915f3cde9523d533e47efe855258e553121d6f431a18;
        targetSlotStateRootBranch[11] =
            0xf374b7407f90e62c78049acb7780d00b4e0728705f1c99bff9ab0f2247bd4f79;
        targetSlotStateRootBranch[12] =
            0x889acf0e17b3690d46d8a42b882464fd3a30ff546f5fa6379e1518242fc206ca;
        targetSlotStateRootBranch[13] =
            0x387f59eb20a5e1294a65966f944f8c98af497c3d6d77cb5dd0a4973c7b2ed77c;
        targetSlotStateRootBranch[14] =
            0x1bd9c412705fd1c99931860d2c23233c6e3775cdbac91ff93c235453267fb732;
        targetSlotStateRootBranch[15] =
            0xc596ac89cdd28ba7680b78d53bf4f9edc68dcb1ca1e2854367c1d2db298aa85b;
        targetSlotStateRootBranch[16] =
            0x21708bd1258c86451ff99644563018000914da5864639c27c917d1aaee968495;
        targetSlotStateRootBranch[17] =
            0xb2d69c5d06778817eb49469fea28edc748ea80ca59309495b2f6ff4e5f07290a;
        targetSlotStateRootBranch[18] =
            0x4c7668e400558472d0ee6e8897355ce48c11e6646bdc9097e0ef77dc21f2d358;
        targetSlotStateRootBranch[19] =
            0x1d74928552a0db9fed3a5344e0655ab6ba422f12fe95cca98a28d3943b8aee23;
        targetSlotStateRootBranch[20] =
            0xa7907a1807ae753e86f018b8096ec68d86b6baf098e1347b2beb7e2cc40cb7ef;
        targetSlotStateRootBranch[21] =
            0xcaa0c0d466c382afb754a047d6f8a01420df3f166cef655b43743ad758e33281;
        targetSlotStateRootBranch[22] =
            0xc171a2c57d669c2e10eec7af1b8fbbc2da7f518499f90aa2346adb4d84b7e8c7;
        targetSlotStateRootBranch[23] =
            0x6a98e7cb86041c8bfef8409a2b0b0687e50e3d5d51ec70d06522578a8bc5d9c4;
        targetSlotStateRootBranch[24] =
            0x7a10ae15a283982b2366bf1cc5574a7bbb8ec7b6f724f18537223c8ec1524f08;
        targetSlotStateRootBranch[25] =
            0xa788a54ef7abad6ad9188bbca48754dffee3eb19d4de1a083c1324ab24279b52;
        targetSlotStateRootBranch[26] =
            0xef9e4f1156c85ace4f2cc7a73029501f0d33ace011b8d1fcb13103ea9acc8475;
        bytes32 receiptsRoot = 0x05911bffdb32343df6d8af53971ade6b8959e1b06ad994715a8080524a2875d2;
        uint256 concatGindex = 162103683;
        bool isValid = SSZ.isValidMerkleBranch(
            receiptsRoot, concatGindex, targetSlotStateRootBranch, srcSlotStateRoot
        );
        assertTrue(isValid);
    }

    function test_ReceiptRootProof_WhenSameSlots() public pure {
        // TODO
    }

    function test_ReceiptRootProof_WhenFarSlots() public pure {
        // TODO
    }
}
