// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "truffle/Assert.sol";
import "../contracts/libs/WittyPixelsLib.sol";

contract TestWittyPixelsLib {
    using WittyPixelsLib for *;

    function testOwnershipDeedsSignatureVerification() external {
        bytes32[] memory proof_ = new bytes32[](3);
        proof_[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[1] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[2] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        WittyPixelsLib.TokenVaultOwnershipDeeds memory deeds = WittyPixelsLib.TokenVaultOwnershipDeeds({
            parentToken: 0xc0ffee3c6F66dE5a0adcCEc65Dc6bB20C8C6A454,
            parentTokenId: 1,
            playerAddress: 0x8d86Bc475bEDCB08179c5e6a4d494EbD3b44Ea8B,
            playerIndex: 5,
            playerPixels: 1235,
            playerPixelsProof: proof_,
            signature: hex"28aac88b7de30e7e82929f2535e907352b45855f070afdc25fe58aa74867233a0ac88ae11cecaede573ecf43b689882a1798b54a8cb5d253d93dedc221fc80311b"
        });
        bytes32 deedsHash = keccak256(abi.encode(
            deeds.parentToken,
            deeds.parentTokenId,
            deeds.playerAddress,
            deeds.playerIndex,
            deeds.playerPixels,
            deeds.playerPixelsProof
        ));
        Assert.equal(
            WittyPixelsLib.recoverAddr(deedsHash, deeds.signature),
            0xF8A654C0328Ba4bAE1aF69EB5856Fc807C8E5731,
            "WittyPixelsLib: bad signature"
        );
    }

    function testMerkleProofLeaves5Good() external {
        bytes32 leaf = keccak256(abi.encode(
            uint(5),
            uint(1235)
        ));
        bytes32[] memory proof_ = new bytes32[](3);
        proof_[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[1] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[2] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        Assert.equal(
            WittyPixelsLib.merkle(proof_, leaf),
            0x0,
            "TestWittyPixelsLib: unexpected bad proof"
        );
    }

    function testMerkleProofLeaves5BadLeaf() external {
        bytes32 leaf = keccak256(abi.encode(
            uint(5),
            uint(1236)
        ));
        bytes32[] memory proof_ = new bytes32[](3);
        proof_[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[1] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[2] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        Assert.notEqual(
            WittyPixelsLib.merkle(proof_, leaf),
            0x0,
            "TestWittyPixelsLib: unexpected valid proof"
        );
    }

    function testMerkleProofLeaves5BadProof() external {
        bytes32 leaf = keccak256(abi.encode(
            uint(5),
            uint(1235)
        ));
        bytes32[] memory proof_ = new bytes32[](3);
        proof_[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[1] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[2] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        Assert.notEqual(
            WittyPixelsLib.merkle(proof_, leaf),
            0x0,
            "TestWittyPixelsLib: unexpected valid proof"
        );
    }

    function testMerkleProofLeaves8Good() external {
        bytes32 leaf = keccak256(abi.encode(
            uint(5),
            uint(1235)
        ));
        bytes32[] memory proof_ = new bytes32[](3);
        proof_[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[1] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[2] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        Assert.equal(
            WittyPixelsLib.merkle(proof_, leaf),
            0x0,
            "TestWittyPixelsLib: unexpected bad proof"
        );
    }

    function testMerkleProofLeaves8BadLeaf() external {
        bytes32 leaf = keccak256(abi.encode(
            uint(5),
            uint(1236)
        ));
        bytes32[] memory proof_ = new bytes32[](3);
        proof_[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[1] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[2] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        Assert.notEqual(
            WittyPixelsLib.merkle(proof_, leaf),
            0x0,
            "TestWittyPixelsLib: unexpected valid proof"
        );
    }

    function testMerkleProofLeaves8BadProof() external {
        bytes32 leaf = keccak256(abi.encode(
            uint(5),
            uint(1235)
        ));
        bytes32[] memory proof_ = new bytes32[](3);
        proof_[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[1] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof_[2] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        Assert.notEqual(
            WittyPixelsLib.merkle(proof_, leaf),
            0x0,
            "TestWittyPixelsLib: unexpected valid proof"
        );
    }

}