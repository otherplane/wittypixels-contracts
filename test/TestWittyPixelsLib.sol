// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "truffle/Assert.sol";
import "../contracts/libs/WittyPixelsLib.sol";

contract TestWittyPixelsLib {
    using WittyPixelsLib for *;

    event Leaf(bytes32 hash);
    event Root(bytes32 hash);

    function testMerkleProofLeaves5Good() external {
        bytes32 leaf = keccak256(abi.encode(
            uint(17),
            uint(23)
        ));
        emit Leaf(leaf);
        bytes32[] memory proof_ = new bytes32[](3);
        proof_[0] = 0x20ea3f905c06089a25c77876ced137bb6b51042bd7f1cff5aa1f9eb2851b0d90;
        proof_[1] = 0x306df6fb2caa2b338dc21474c97d7dd9d36d2842dee9a92642799ecb27faf1d6;
        proof_[2] = 0xde31a920dbdd1f015b2a842f0275dc8dec6a82ff94d9b796a36f23c64a3c8332;
        bytes32 root = WittyPixelsLib.merkle(proof_, leaf);
        emit Root(root);
        Assert.equal(
            root,
            0xdaa20a043a0d291c2fe2fe518d35b6d471136321d760e29d5d48edeba5b7c5c9,
            "TestWittyPixelsLib: unexpected bad proof"
        );
    }

    function testMerkleProofLeaves5BadLeaf() external {
        bytes32 leaf = keccak256(abi.encode(
            uint(17),
            uint(9999)
        ));
        emit Leaf(leaf);
        bytes32[] memory proof_ = new bytes32[](3);
        proof_[0] = 0x20ea3f905c06089a25c77876ced137bb6b51042bd7f1cff5aa1f9eb2851b0d90;
        proof_[1] = 0x306df6fb2caa2b338dc21474c97d7dd9d36d2842dee9a92642799ecb27faf1d6;
        proof_[2] = 0xde31a920dbdd1f015b2a842f0275dc8dec6a82ff94d9b796a36f23c64a3c8332;
        bytes32 root = WittyPixelsLib.merkle(proof_, leaf);
        emit Root(root);
        Assert.notEqual(
            root,
            0xdaa20a043a0d291c2fe2fe518d35b6d471136321d760e29d5d48edeba5b7c5c9,
            "TestWittyPixelsLib: unexpected valid proof"
        );
    }

    function testMerkleProofLeaves5BadProof() external {
        bytes32 leaf = keccak256(abi.encode(
            uint(17),
            uint(23)
        ));
        emit Leaf(leaf);
        bytes32[] memory proof_ = new bytes32[](3);
        proof_[2] = 0x20ea3f905c06089a25c77876ced137bb6b51042bd7f1cff5aa1f9eb2851b0d90;
        proof_[0] = 0x306df6fb2caa2b338dc21474c97d7dd9d36d2842dee9a92642799ecb27faf1d6;
        proof_[1] = 0xde31a920dbdd1f015b2a842f0275dc8dec6a82ff94d9b796a36f23c64a3c8332;
        bytes32 root = WittyPixelsLib.merkle(proof_, leaf);
        emit Root(root);
        Assert.notEqual(
            root,
            0xdaa20a043a0d291c2fe2fe518d35b6d471136321d760e29d5d48edeba5b7c5c9,
            "TestWittyPixelsLib: unexpected valid proof"
        );
    }

     function testMerkleProofLeaves9Good() external {
        bytes32 leaf = keccak256(abi.encode(
            uint(49),
            uint(0)
        ));
        emit Leaf(leaf);
        bytes32[] memory proof_ = new bytes32[](4);
        proof_[0] = 0xd3d19a62491178309c24d901a5f5d13c31ca07d47b0cddca25a2a73f6f30d4b0;
        proof_[1] = 0xd00c516fbd2d30ae0f5b9a4772d5210620a541797ce4157cfe66eb50b636f208;
        proof_[2] = 0x44246914b6905c3d48b4e57781e66199b274c84c8a434a8fc9c58d26482e20ad;
        proof_[3] = 0xe9087ebbcd7c881ce19b43771bad3bdfcf1aa1bb85d25373d929e553193bbada;
        bytes32 root = WittyPixelsLib.merkle(proof_, leaf);
        emit Root(root);
        Assert.equal(
            root,
            0xf6b0c1acdfaea501dd80f5c8d228006aa6612cf960605011843de23c5633b905,
            "TestWittyPixelsLib: unexpected bad proof"
        );
    }
}