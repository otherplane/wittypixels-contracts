const utils = require("../scripts/utils")
const { BN, expectEvent, expectRevert } = require("@openzeppelin/test-helpers")
const { assert } = require("chai")

const { MerkleTree } = require('merkletreejs')
const keccak256 = (x) => {
    // console.log("x =>", x.toString('hex'))
    var h = web3.utils.soliditySha3({
        t: 'bytes',
        v: "0x" + x.toString('hex')
    })
    // console.log("h =>", h)
    // console.log()
    return h
}

contract("MerkleTree.js", () => {
    
    var playersA1 = [
        { index: 0, pixels: 5 },
        { index: 17, pixels: 23 },
        { index: 3, pixels: 77 },
        { index: 123, pixels: 0 },
        { index: 521, pixels: 69 },
    ]
    var playersA2 = [
        { index: 17, pixels: 23 },
        { index: 0, pixels: 5 },
        { index: 3, pixels: 77 },
        { index: 123, pixels: 0 },
        { index: 521, pixels: 69 },
    ]
    var playersB1 = [
        { index: 17, pixels: 23 },
        { index: 0, pixels: 5 },
        { index: 3, pixels: 77 },
        { index: 123, pixels: 0 },
        { index: 521, pixels: 69 },
        { index: 1234, pixels: 33 },
        { index: 189, pixels: 23 },
        { index: 49, pixels: 0 },
        { index: 124, pixels: 13 },
    ]
    var leavesA1 = mapLeaves(playersA1)
    var leavesA2 = mapLeaves(playersA2)
    var leavesB1 = mapLeaves(playersB1)
    var merkleA1 = new MerkleTree(leavesA1, keccak256, { sort: true })
    var merkleA2 = new MerkleTree(leavesA2, keccak256, { sort: true })
    var merkleB1 = new MerkleTree(leavesB1,  keccak256, { sort: true })    
    var proofIndex17A1 = getProof(merkleA1, leavesA1[1])
    var proofIndex17A2 = getProof(merkleA2, leavesA2[0])
    var proofIndex49B1 = getProof(merkleB1, leavesB1[7])

    it("roots of permuted maps match", async () => {
        // console.log("A1.leaves =>", JSON.stringify(leavesA1))
        // console.log("A1.leaves =>", JSON.stringify(leavesA2))
        // console.log("B1.leaves =>", JSON.stringify(leavesB1))
        // console.log("A1"); console.log(merkleA1.toString())
        // console.log("A2"); console.log(merkleA2.toString())
        console.log("B1"); console.log(merkleB1.toString())
        assert.equal(getRoot(merkleA1), getRoot(merkleA2))
    })

    it("proofs of same leaf in permuted maps match", async () => {        
        // console.log("proofIndex17A1 =>", proofIndex17A1)
        // console.log("proofIndex17A2 =>", proofIndex17A2)
        // console.log("proofIndex49B1=>", proofIndex49B1)
        assert.equal(proofIndex17A1.length, proofIndex17A2.length)
        for (var i = 0; i < proofIndex17A1.length; i ++) {
            assert.equal(proofIndex17A1[i], proofIndex17A2[i])
        }
    })

}) 

function mapLeaves(players) {
    return players.map(p => {
        return web3.utils.soliditySha3(
            { t: 'uint256', v: new BN(p.index) },
            { t: 'uint256', v: new BN(p.pixels)},
        )
    })
}

function getProof(merkle, leaf) {
    return merkle.getProof(leaf).map(x => "0x" + x.data.toString('hex'))
}

function getRoot(merkle) {
    return "0x" + merkle.getRoot().toString('hex')
}