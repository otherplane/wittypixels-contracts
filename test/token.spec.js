const utils = require("../scripts/utils")
const { BN, expectEvent, expectRevert } = require("@openzeppelin/test-helpers")
const { assert } = require("chai")
const { expectRevertCustomError } = require("custom-error-test-helper")

const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetProxy = artifacts.require("WitnetProxy")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoardTrustableDefault")
const WitnetRequestTemplate = artifacts.require("WitnetRequestTemplate")
const WitnetRequestImageDigest = artifacts.require("WitnetRequestImageDigest")
const WitnetRequestTokenStats = artifacts.require("WitnetRequestTokenStats")
const WittyPixelsToken = artifacts.require("WittyPixelsToken")
const WittyPixelsTokenVault = artifacts.require("WittyPixelsTokenVault")

const settings = require("../migrations/settings")

var bytecodes
var implementation
var prototype
var proxy    
var token
var tokenVault
var witnet

contract("WittyPixels", ([ curator, master, stranger, player ]) => {

    before(async () => {
        bytecodes = await WitnetBytecodes.deployed()
        implementation = await WittyPixelsToken.deployed()
        prototype = await WittyPixelsTokenVault.deployed()
        proxy = await WitnetProxy.new({ from: master })
        token = await WittyPixelsToken.at(proxy.address)
        witnet = await WitnetRequestBoard.deployed()
    })

    context(`Token implementation address`, async () => {
    
        context("WittyPixelsUpgradeableBase", async () => {
            it("deployed as an upgradable implementation", async() => {
                assert(await implementation.isUpgradable())
            })
            it("owner address is set to zero", async () => {
                assert.equal(await implementation.owner.call(), "0x0000000000000000000000000000000000000000")
            })
            it("cannot transfer ownership", async () => {
                await expectRevert(
                    implementation.transferOwnership(curator, { from: master }),
                    "not the owner"
                )
            })
            it("cannot acquire ownership", async () => {
                await expectRevert(
                    implementation.acceptOwnership({ from: master }),
                    "not the new owner"
                )
            })
            it("base addressess matches instance address", async () => {
                assert.equal(implementation.address, await implementation.base.call())
            })
            it("cannot be initialized", async () => {
                await expectRevert(
                    implementation.initialize(
                        web3.eth.abi.encodeParameter(
                            "string[3]", [
                                settings.core.collection.baseURI,
                                settings.core.collection.name,
                                settings.core.collection.symbol
                            ]
                        ),
                        { from: master }
                    ), "not a delegate call"
                )
            })
        })
        
        context("IWittyPixelsToken", async () => {
            it("name() returns empty string", async () => {
                assert.equal(await implementation.name.call(), "")
            })
            it("symbol() returns empty string", async () => {
                assert.equal(await implementation.symbol.call(), "")
            })
            it("getTokenStatusString(0) reverts", async () => {
                await expectRevert(implementation.getTokenStatusString.call(0), "not initialized");
            })
            it("getTokenStatusString(1) reverts", async () => {
                await expectRevert(implementation.getTokenStatusString.call(1), "not initialized");
            })
            it("metadata(0) reverts with unknown token", async () => {
                await expectRevert(
                    implementation.metadata.call(0),
                    "unknown token"
                )
            })
            it("metadata(1) reverts with unknown token", async () => {
                await expectRevert(
                    implementation.metadata.call(1),
                    "unknown token"
                )
            })
            it("totalSupply() returns 0", async () => {
                assert.equal(await implementation.totalSupply.call(), 0)
            })
        })
        
        context("IWittyPixelsTokenAdmin", async () => {
            it("cannot launch new event", async () => {
                await expectRevert(
                    implementation.launch([
                        settings.core.events[0].name,
                        settings.core.events[0].venue,
                        settings.core.events[0].startTs,
                        settings.core.events[0].endTs
                    ], { from: master }),
                    "not the owner"
                )
            })
            it("baseURI cannot be set", async () => {
                await expectRevert(
                    implementation.setBaseURI(settings.core.collection.baseURI, { from: master }),
                    "not the owner"
                )
            })
        })
        
        context("IWittyPixelsTokenJackpots", async () => {
            it("jackpots count for token #1 is zero", async () => {
                assert.equal(await implementation.getTokenJackpotsCount(1), 0)
            })
        })
        
        context("ITokenVaultFactory", async () => {
            it("token vault prototype addess is zero", async () => {
                assert.equal(await implementation.tokenVaultPrototype.call(), "0x0000000000000000000000000000000000000000")
            })
            it("token vaults count is zero", async () => {
                assert.equal(await implementation.totalTokenVaults.call(), 0)
            })
            it.skip("fractionalizing external collections is not supported", async () => {
                await expectRevert(
                    implementation.fractionalize(
                        implementation.address, 1, [
                            settings.core.events[0].auction.deltaPrice,
                            settings.core.events[0].auction.deltaSeconds,
                            settings.core.events[0].auction.reservePrice,
                            settings.core.events[0].auction.startingPrice,
                            settings.core.events[0].auction.startingTs,
                        ], { from: master }
                    ), "not implemented"
                )
            })
            it("fractionalizing first token is not possible", async () => {
                await expectRevert(
                    implementation.fractionalize(
                        1,
                        web3.eth.abi.encodeParameter(
                            "uint256[5]", [
                                "0x" + new BN(settings.core.events[0].auction.deltaPrice),
                                settings.core.events[0].auction.deltaSeconds,
                                "0x" + new BN(settings.core.events[0].auction.reservePrice),
                                "0x" + new BN(settings.core.events[0].auction.startingPrice),
                                settings.core.events[0].auction.startingTs,
                            ]
                        ), { from: master }
                    ), "not initialized"
                )
            })
        })
    })
    
    context("Proxy address as a WitnetProxy", async () => {
        
        context("Before being initialized:", async () => {
            it("proxy implementation address is zero", async () => {
                assert.equal(await proxy.implementation.call(), "0x0000000000000000000000000000000000000000")
            })
        })
        
        context("Upon initialization:", async () => {
            it("fails if trying to initialize proxy with a bad baseURI", async () => {
                await expectRevert(
                    proxy.upgradeTo(
                        implementation.address,
                        web3.eth.abi.encodeParameter(
                            "string[3]", [
                                "https://wittypixels.art",
                                settings.core.collection.name,
                                settings.core.collection.symbol
                            ]
                        ), { from: master }
                    ), "unable to initialize"
                )
            })
            it("works if trying to initialize proxy for the first time with a well-formed baseURI", async () => {
                await proxy.upgradeTo(
                    implementation.address,
                    web3.eth.abi.encodeParameter(
                        "string[3]", [
                            settings.core.collection.baseURI,
                            settings.core.collection.name,
                            settings.core.collection.symbol
                        ]
                    ), { from: master }
                )
            })
            it("proxy implementation address updates accordingly", async () => {
                assert.equal(await proxy.implementation.call(), implementation.address)
            })
        })
        
        context("After first initialization:", async () => {
            it("owner cannot upgrade proxy to same implementation more than once", async () => {
                await expectRevert(
                    proxy.upgradeTo(implementation.address, "0x", { from: master }),
                    "nothing to upgrade"
                )
            })
            it("stranger cannot upgrade proxy, ever", async () => {
                implementation = await WittyPixelsToken.new(
                    WitnetRequestImageDigest.address,
                    WitnetRequestTokenStats.address,
                    true,
                    "0x0",
                )
                await expectRevert(
                    proxy.upgradeTo(implementation.address, "0x", { from: stranger }),
                    "not authorized"
                )
            })
            it("fails if trying to upgrade to something without same proxiableUUID()", async () => {
                await expectRevert.unspecified(proxy.upgradeTo(WitnetRequestImageDigest.address, "0x", { from: master }))
            })
            it("fails if trying to upgrade to proxy address itself", async () => {
                await expectRevert(
                    proxy.upgradeTo(proxy.address, "0x", { from: master }),
                    "unable to initialize"
                )
            })
            it("owner can upgrade proxy to new implementation address", async () => {                
                await proxy.upgradeTo(implementation.address, "0x", { from: master })
            })
            it("proxy implementation address updates accordingly", async () => {
                assert.equal(await proxy.implementation.call(), implementation.address)
            })
        })
    })
    
    context("Token proxy address as a token", async () => {

        context("ERC721Metadata", async () => {
            it("baseURI() returns expected string", async () => {
                assert.equal(await token.baseURI.call(), settings.core.collection.baseURI)
            })
            it("name() returns expected string", async () => {
                assert.equal(await token.name.call(), settings.core.collection.name)
            })
            it("symbol() returns expected string", async () => {
                assert.equal(await token.symbol.call(), settings.core.collection.symbol)
            })
        })

        context("WittyPixelsUpgradeableBase", async () => {
            it("owner address is set as expected", async () => {
                assert.equal(await token.owner.call(), master)
            })
            it("stranger cannot transfer ownership", async () => {
                await expectRevert(
                    token.transferOwnership(curator, { from: stranger }),
                    "not the owner"
                )
            })
            it("owner can start transferring ownership", async () => {
                await token.transferOwnership(curator, { from: master })
            })
            it("owner can recover ownership", async () => {
                await token.transferOwnership(master, { from: master })
            })
            it("pending owner is updated accordingly", async () => {
                assert.equal(await token.pendingOwner.call(), master)
            })
            it("stranger cannot accept pending ownership", async () => {
                await token.transferOwnership(curator, { from: master })
                await expectRevert(
                    token.acceptOwnership({ from: stranger }),
                    "not the new owner"
                )
            })
            it("new owner can accept ownership", async () => {
                await token.acceptOwnership({ from: curator })
            })
            it("proxiableUUID() returns expected value", async () => {
                assert.equal(
                    await token.proxiableUUID.call(),
                    web3.utils.soliditySha3("art.wittypixels.token")
                )
            })
            it("no one can initialize same implementation more than once", async () => {
                await expectRevert(
                    token.initialize("0x", { from: curator }),
                    "already initialized"
                )
                await expectRevert(
                    token.initialize("0x", { from: stranger }),
                    "not the owner"
                )
            })
        })

        context("NFT token #1", async () => {
            context("Before launching:", async () => {
                it("token status is 'Void'", async () => {
                    assert.equal(await token.getTokenStatusString.call(1), "Void" )
                })
                it("imageURI(1) returns empty string", async () => {
                    assert.equal(await token.imageURI.call(1), "")
                })
                it("stranger cannot launch next token", async () => {
                    await expectRevert(
                        token.launch([
                                settings.core.events[0].name,
                                settings.core.events[0].venue,
                                settings.core.events[0].startTs,
                                settings.core.events[0].endTs
                            ],
                            { from: stranger }
                        ), "not the owner"
                    )
                })
                it("owner cannot launch event with bad timestamps", async () => {
                    await expectRevert(
                        token.launch([
                                settings.core.events[0].name,
                                settings.core.events[0].venue,
                                settings.core.events[0].startTs,
                                0
                            ],
                            { from: curator }
                        ), "bad timestamps"
                    )
                    await expectRevert(
                        token.launch([
                                settings.core.events[0].name,
                                settings.core.events[0].venue,
                                settings.core.events[0].endTs,
                                settings.core.events[0].startTs,
                            ],
                            { from: curator }
                        ), "bad timestamps"
                    )
                })
                it("owner cannot start minting", async() => {
                    await expectRevert(
                        token.mint(
                            1,
                            "0x738a610e267ba49e7d22c96a5f59740e88a10ba8a942047052e57dc3e69c0a64",
                            { from: curator }
                        ), "bad mood"
                    )
                })
            })
            context("Upon launching:", async () => {
                it("owner can launch next token with valid timestamps", async () => {
                    await token.launch([
                            settings.core.events[0].name,
                            settings.core.events[0].venue,
                            settings.core.events[0].startTs,
                            settings.core.events[0].endTs
                        ],
                        { from: curator }
                    )
                })
                it("owner can reset token's event in 'Launching' status", async () => {
                    await token.launch([
                            settings.core.events[0].name,
                            settings.core.events[0].venue,
                            Math.round(Date.now() / 1000) - 86400,
                            Math.round(Date.now() / 1000) - 86400,
                        ],
                        { from: curator }
                    )
                })
            })
            context("After launch:", async () => {
                it("token status changed to 'Launching'", async () => {
                    assert.equal(await token.getTokenStatusString.call(1), "Launching" )
                })
                it("getTokenMetadata(1) should contain event data only", async () => {
                    var metadata = await token.getTokenMetadata.call(1)
                    assert.equal(metadata.theEvent.name, settings.core.events[0].name)
                })
                it("tokenURI(1) must still fail", async () => {
                    await expectRevert(
                        token.tokenURI.call(1),
                        "unknown token"
                    )
                })
                it("totalSupply() should still be 0", async () => {
                    assert.equal(await token.totalSupply.call(), 0)
                })
                it("token #2 status should still be 'Void'", async () => {
                    assert.equal(await token.getTokenStatusString.call(2), "Void")
                })
                it("owner can still change baseURI", async () => {
                    await token.setBaseURI(settings.core.collection.baseURI, { from: curator })
                })
                it("stranger cannot change baseURI", async () => {
                    await expectRevert(
                        token.setBaseURI(settings.core.collection.baseURI, { from: stranger }),
                        "not the owner"
                    )
                })
            })
            context("Upon minting:", async () => {
                it("stranger cannot start minting", async () => {
                    await expectRevert(
                        token.mint(
                            1,
                            "0x738a610e267ba49e7d22c96a5f59740e88a10ba8a942047052e57dc3e69c0a64",
                            { from: stranger }
                        ), "not the owner"
                    )
                })
                it("owner can start minting", async () => {
                    await token.mint(
                        1,
                        "0x738a610e267ba49e7d22c96a5f59740e88a10ba8a942047052e57dc3e69c0a64", 
                        { from: curator, gas: 3000000, value: 10 ** 18 }
                    )
                })
            })
            context("After minting:", async () => {
                var witnetRequestImageDigest
                var witnetRequestTokenStats
                it("token status changes to 'Minting'", async () => {
                    assert.equal(await token.getTokenStatusString.call(1), "Minting")
                })
                it("getTokenMetadata(1) should contain expected data", async () => {
                    var metadata = await token.getTokenMetadata.call(1)
                    assert.notEqual(metadata.birthTs, 0)
                })
                it("getTokenWitnetRequests(1) should return valid WitnetRequestTemplate instances", async () => {
                    var requests = await token.getTokenWitnetRequests.call(1)
                    witnetRequestImageDigest = requests[0]
                    witnetRequestTokenStats = requests[1]
                })
                it("metadata(1) still reverts", async () => {
                    await expectRevert(
                        token.metadata.call(1),
                        "unknown token"
                    )
                })
                it("owner can re-start requests in 'Minting' status", async () => {
                    await token.mint(
                        1,
                        "0x738a610e267ba49e7d22c96a5f59740e88a10ba8a942047052e57dc3e69c0a64",
                        { from: curator, value: 10 ** 18 }
                    )
                    var requests = await token.getTokenWitnetRequests.call(1)
                    assert.notEqual(requests[0], witnetRequestImageDigest)
                    assert.notEqual(requests[1], witnetRequestTokenStats)
                })
                it("totalSupply() should still be 0", async () => {
                    assert.equal(await token.totalSupply.call(), 0)
                })
                it("token #2 status should still be 'Void'", async () => {
                    assert.equal(await token.getTokenStatusString.call(2), "Void")
                })
                it("owner cannot change event data anymore", async () => {
                    await expectRevert(
                        token.launch(
                            [
                                settings.core.events[0].name,
                                settings.core.events[0].venue,
                                settings.core.events[0].startTs,
                                settings.core.events[0].endTs
                            ], { from: curator }
                        ), "bad mood"
                    )
                })
                it("owner cannot fractionalize while a token vault prototype is not set", async () => {
                    await expectRevert(
                        token.fractionalize(
                            1,
                            web3.eth.abi.encodeParameter(
                                "uint256[5]", [
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                ]
                            ),
                            { from: curator }
                        ), "no token vault prototype"
                    )
                })
                it("stranger cannot set token vault prototype", async () => {
                    await expectRevert(
                        token.setTokenVaultPrototype(prototype.address, { from: stranger}),
                        "not the owner"
                    )
                })
                it("fails if owner tries to set uncompliant token vault prototype", async () => {
                    await expectRevert(
                        token.setTokenVaultPrototype(implementation.address, { from: curator }),
                        "uncompliant"
                    )
                })
                it("owner can set a compliant token vault protoype", async () => {
                    await token.setTokenVaultPrototype(prototype.address, { from: curator })
                    assert.equal(prototype.address, await token.tokenVaultPrototype.call())
                })
                it("owner cannot fractionalize while Witnet data requests are not solved", async () => {
                    await expectRevert(
                        token.fractionalize(
                            1,
                            web3.eth.abi.encodeParameter(
                                "uint256[5]", [
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                ]
                            ),
                            { from: curator }
                        ), "no value yet"
                    )
                })
            })
            context("Upon Witnet data requests being solved:", async () => {
                context("with unexpected result types...", async () => {
                    before(async() => {
                        var requests = await token.getTokenWitnetRequests.call(1)
                        var witnetRequestImageDigest = await WitnetRequestTemplate.at(requests[0])
                        var witnetRequestTokenStats = await WitnetRequestTemplate.at(requests[1])
                        var imageDigestId = await witnetRequestImageDigest.lastAttemptId.call()
                        var tokenStatsId = await witnetRequestTokenStats.lastAttemptId.call()
                        // console.log("imageDigestId =>", imageDigestId)
                        // console.log("tokenStats =>", tokenStatsId)
                        await witnet.reportResult(
                            imageDigestId,
                            "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
                            "0x66737472696E67", // "string"
                            { from: master }
                        )
                        await witnet.reportResult(
                            tokenStatsId,
                            "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
                            // "0x8478423078646561646265656664656164626565666465616462656566646561646265656664656164626565666465616462656566646561646265656664656164626565661904D2187B193039",
                                // [ "0xdeadbeef...", 1234, 123, 12345]
                            "0x88784064656164626565666465616462656566646561646265656664656164626565666465616462656566646561646265656664656164626565666465616462656566782E516D504B317333704E594C693945526971334244784B6134586F736757774652515579644855747A3459677071421901F41904D21903E81909291901591910E1",
                                // [ "deadbeef...", "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB", 500, 1234, 1000, 2345, 345, 4321]
                            { from: master }
                        )
                        // var digestValue = await witnetRequestImageDigest.lastValue.call()
                        // var statsValue = await witnetRequestTokenStats.lastValue.call()    
                        // assert.equal(digestValue[1], "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef")
                        // assert.equal(statsValue[1], "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef")

                        // console.log("witnet =>", witnet.address)
                        // console.log("witnetRequestImageDigest.witnet =>", await witnetRequestImageDigest.witnet.call())
                                            
                        // digestValue = web3.eth.abi.decodeParameter("uint256", digestValue[0])
                        // statsValue = web3.eth.abi.decodeParameter({
                        //     "ERC721TokenStats": {
                        //         "pixelsRoot": "bytes32",
                        //         "totalPixels": "uint256", 
                        //         "totalPlayers": "uint256", 
                        //         "totalScans": "uint256" 
                        //     }}, statsValue[0]
                        // )
                        // console.log("digestValue =>", digestValue)
                        // console.log("statsValue =>", statsValue)
                        
                    })
                    it("fractionalizing fails with expected revert message", async () => {
                        await expectRevert(
                            token.fractionalize(
                                1,
                                web3.eth.abi.encodeParameter(
                                    "uint256[5]", [
                                        0,//new BN(settings.core.events[0].auction.deltaPrice),
                                        0,//new BN(settings.core.events[0].auction.deltaSeconds),
                                        0,//new BN(settings.core.events[0].auction.reservePrice),
                                        0,//new BN(settings.core.events[0].auction.startingPrice),
                                        0,//new BN(settings.core.events[0].auction.startingTs),
                                    ]
                                ),
                                { from: curator }
                            ), "cannot deserialize image"
                        )
                    })
                })
                context("with badly formed merkle root...", async () => {
                    before(async() => {
                        await token.mint(
                            1,
                            "0x738a610e267ba49e7d22c96a5f59740e88a10ba8a942047052e57dc3e69c0a64", 
                            { from: curator, gas: 3000000, value: 10 ** 18 }
                        )
                        var requests = await token.getTokenWitnetRequests.call(1)
                        var witnetRequestImageDigest = await WitnetRequestTemplate.at(requests[0])
                        var witnetRequestTokenStats = await WitnetRequestTemplate.at(requests[1])
                        var imageDigestId = await witnetRequestImageDigest.lastAttemptId.call()
                        var tokenStatsId = await witnetRequestTokenStats.lastAttemptId.call()
                        await witnet.reportResult(
                            imageDigestId,
                            "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
                            "0x1A006691B7", // uint64(6721975)
                            { from: master }
                        )
                        await witnet.reportResult(
                            tokenStatsId,
                            "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
                            //"0x8478423078646561646265656664656164626565666465616462656566646561646265656664656164626565666465616462656566646561646265656664656164626565661904D2187B193039",
                                // [ "0xdeadbeef...", 1234, 123, 12345]
                            "0x887842307864656164626565666465616462656566646561646265656664656164626565666465616462656566646561646265656664656164626565666465616462656566782E516D504B317333704E594C693945526971334244784B6134586F736757774652515579644855747A3459677071421901F41904D21903E81909291901591910E1",
                                // [ "0xdeadbeef...", "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB", 500, 1234, 1000, 2345, 345, 4321]
                            { from: master }
                        )
                    })
                    it("fractionalizing fails with expected revert message", async () => {
                        await expectRevert(
                            token.fractionalize(
                                1,
                                web3.eth.abi.encodeParameter(
                                    "uint256[5]", [
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                    ]
                                ),
                                { from: curator }
                            ), "invalid hex"
                        )
                    })
                })
                context("with valid results...", async () => {
                    before(async() => {
                        await token.mint(
                            1,
                            "0x738a610e267ba49e7d22c96a5f59740e88a10ba8a942047052e57dc3e69c0a64", 
                            { from: curator, gas: 3000000, value: 10 ** 18 }
                        )
                        var requests = await token.getTokenWitnetRequests.call(1)
                        var witnetRequestImageDigest = await WitnetRequestTemplate.at(requests[0])
                        var witnetRequestTokenStats = await WitnetRequestTemplate.at(requests[1])
                        var imageDigestId = await witnetRequestImageDigest.lastAttemptId.call()
                        var tokenStatsId = await witnetRequestTokenStats.lastAttemptId.call()
                        await witnet.reportResult(
                            imageDigestId,
                            "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
                            "0x1A006691B7", // uint64(6721975)
                            { from: master }
                        )
                        await witnet.reportResult(
                            tokenStatsId,
                            "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
                            "0x88784064656164626565666465616462656566646561646265656664656164626565666465616462656566646561646265656664656164626565666465616462656566782E516D504B317333704E594C693945526971334244784B6134586F736757774652515579644855747A3459677071421901F41904D21903E81909291901591910E1",
                                // [ "deadbeef...", "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB", 500, 1234, 1000, 2345, 345, 4321]
                            { from: master }
                        )
                    })
                    it("owner cannot fractionalize if providing invalid auction settings", async () => {
                        await expectRevert(
                            token.fractionalize(
                                1,
                                web3.eth.abi.encodeParameter(
                                    "uint256[5]", [
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                    ]
                                ),
                                { from: curator }
                            ), "bad settings"
                        )
                    })
                    it("stranger cannot fractionalize even if providing valid auction settings", async () => {
                        await expectRevert(
                            token.fractionalize(
                                1,
                                web3.eth.abi.encodeParameter(
                                    "uint256[5]", [
                                        "0x" + new BN(settings.core.events[0].auction.deltaPrice),
                                        settings.core.events[0].auction.deltaSeconds,
                                        "0x" + new BN(settings.core.events[0].auction.reservePrice),
                                        "0x" + new BN(settings.core.events[0].auction.startingPrice),
                                        settings.core.events[0].auction.startingTs,
                                    ]
                                ),
                                { from: stranger }
                            ), "not the owner"
                        )
                    })
                    it("owner can fractionalize if providing valid auction settings", async () => {
                        var deltaPriceBN = "0x" + utils.padLeft((new BN(settings.core.events[0].auction.deltaPrice)).toString(16), "0", 64)
                        var reservePriceBN = "0x" + utils.padLeft((new BN(settings.core.events[0].auction.reservePrice)).toString(16), "0", 64)
                        var startingPriceBN = "0x" + utils.padLeft((new BN(settings.core.events[0].auction.startingPrice)).toString(16), "0", 64)
                        var tx = await token.fractionalize(
                            1,
                            web3.eth.abi.encodeParameter(
                                "uint256[5]", [
                                    deltaPriceBN,
                                    settings.core.events[0].auction.deltaSeconds,
                                    reservePriceBN,
                                    startingPriceBN,
                                    settings.core.events[0].auction.startingTs,
                                ]
                            ),
                            { from: curator }
                        )
                        var logs = tx.logs.filter(log => log.event === "Fractionalized")
                        assert.equal(logs.length, 1, "'Fractionalized' was not emitted")
                        tokenVault = await WittyPixelsTokenVault.at(logs[0].args.tokenVault)
                    })
                })
            })
            context("After being fractionalized:", async () => {
                var metadata
                it("owner cannot fractionalize the same token again", async () => {
                    await expectRevert(
                        token.fractionalize(
                            1,
                            web3.eth.abi.encodeParameter(
                                "uint256[5]", [
                                    "0x" + new BN(settings.core.events[0].auction.deltaPrice),
                                    settings.core.events[0].auction.deltaSeconds,
                                    "0x" + new BN(settings.core.events[0].auction.reservePrice),
                                    "0x" + new BN(settings.core.events[0].auction.startingPrice),
                                    settings.core.events[0].auction.startingTs,
                                ]
                            ),
                            { from: stranger }
                        ), "bad mood"
                    )
                })
                it("token status changes to 'Fractionalized'", async () => {
                    assert.equal(await token.getTokenStatusString.call(1), "Fractionalized")
                })
                it("totalSupply() should change to 1", async () => {
                    assert.equal(await token.totalSupply.call(), 1)
                })
                it("token #2 status should still be 'Void'", async () => {
                    assert.equal(await token.getTokenStatusString.call(2), "Void")
                })
                it("getTokenMetadata(1) should contain expected data", async () => {
                    var metadata = await token.getTokenMetadata.call(1)
                    assert.equal(metadata.theStats.totalPixels, 2345)
                })
                it("ownerOf(1) should match getTokenVault(1)", async () => {
                    assert.equal(
                        await token.ownerOf.call(1),
                        await token.getTokenVault.call(1)
                    )
                })
                it("metadata(1) should not revert anymore", async () => {
                    metadata = await token.metadata.call(1)
                })
                it("JSON string returned by metadata(1) is well formed", async () => {
                    JSON.parse(metadata)
                })
                it("token vault contract was properly initialized", async () => {
                    var cloned = await tokenVault.cloned.call()
                    var initialized = await tokenVault.initialized.call()
                    var self = await tokenVault.self.call()
                    await tokenVault.version.call()
                    await tokenVault.name.call()
                    var symbol = await tokenVault.symbol.call()
                    var tokenCurator = await tokenVault.curator.call()
                    var totalPixels = await tokenVault.totalPixels.call()
                    var totalSupply = await tokenVault.totalSupply.call()
                    var price = await tokenVault.price.call()                    
                    var nextPriceTimestamp = await tokenVault.nextPriceTimestamp.call()
                    var info = await tokenVault.getInfo.call()
                    var authorsCount = await tokenVault.getAuthorsCount.call()
                    var jackpotsCount = await tokenVault.getJackpotsCount.call()
                    var randomized = await tokenVault.randomized.call()
                    var auctioning = await tokenVault.auctioning.call()
                    await tokenVault.settings.call()                    
                    assert.equal(cloned, true, "not cloned")
                    assert.equal(initialized, true, "not initialized")
                    assert.equal(self, prototype.address, "unexpected self")
                    assert.equal(symbol, settings.core.collection.symbol, "bad symbol")
                    assert.equal(tokenCurator, curator, "bad curator")
                    assert.equal(totalPixels.toString(), "1234", "bad total pixels")
                    assert.equal(totalSupply.toString(), "1234000000000000000000", "bad total supply")
                    assert.equal(price, "32000000000000000000", "unexpected initial price")
                    assert.equal(nextPriceTimestamp.toString(), settings.core.events[0].auction.startingTs, "bad auction start timestamp")
                    assert.equal(info.status.toString(), "0", "vault not in 'Awaiting status")
                    assert.equal(info.stats.totalPixels, totalPixels, "bad vault info.stats.totalPixels")
                    assert.equal(info.currentPrice.toString(), price.toString(), "bad vault info.currentPrice")
                    assert.equal(info.nextPriceTs.toString(), nextPriceTimestamp.toString(), "bad vault info.nextPriceTs")
                    assert.equal(authorsCount.toString(), "0", "bad authors count")
                    assert.equal(jackpotsCount.toString(), "0", "bad jackpots count")
                    assert.equal(randomized, false)
                    assert.equal(auctioning, false)
                })
            })
        })

        context("NFT token vault #1", async () => {
            var info
            context("On 'Awaiting' status:", async () => {
                before(async () => {
                    info = await tokenVault.getInfo.call()
                    if (info.status.toString() !== "0") {
                        console.error("tokenVault: could not reach 'Awaiting' status")
                        process.exit(1)
                    }
                })
            })
            context("On 'Auctioning' status:", async () => {
            })
            context("On 'Sold' status:", async () => {
            })
        })   
    })
    
    

})