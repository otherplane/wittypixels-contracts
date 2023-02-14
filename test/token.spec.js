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

contract("WittyPixels", ([curator, master, stranger, player, player2, patron]) => {

    var backend, backendWallet
    var bytecodes
    var implementation
    var prototype
    var proxy    
    var token
    var tokenVault
    var witnet
    
    before(async () => {
        bytecodes = await WitnetBytecodes.deployed()
        implementation = await WittyPixelsToken.deployed()
        prototype = await WittyPixelsTokenVault.deployed()
        witnet = await WitnetRequestBoard.deployed()
        backendWallet = await web3.eth.accounts.privateKeyToAccount(
            '0x0000000000000000000000000000000000000000000000000000000000000001'
        )
        backend = backendWallet.address
    })

    context(`Token implementation address`, async () => {

        before(async () => {
            proxy = await WitnetProxy.new({ from: master })
            token = await WittyPixelsToken.at(proxy.address)
    
        })
    
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

    context("Token vault prototype address", async () => {
        context("WittyPixelsClonableBase", async () => {
            it("deployed uninitialized", async() => {
                assert.equal(await prototype.initialized(), false)
            })
            it("deployed as no clone", async () => {
                assert.equal(await prototype.cloned(), false)
            })
            it("self address matches instance address", async () => {
                assert.equal(prototype.address, await prototype.self.call())
            })
        })
        context("ERC20Upgradeable", async () => {
            it("name() returns expected deployed with no name", async() => {
                assert.equal(await prototype.name(), "")
            })
            it("deployed witn no symbol", async () => {
                assert.equal(await prototype.symbol(), "")
            })
            it("deployed with no supply", async () => {
                assert.equal((await prototype.totalSupply.call()).toString(), "0")
            })
        })
        context("IWittyPixelsTokenVault", async () => {
            it("getAuthorsCount() reverts", async() => {
                await expectRevert(
                    prototype.getAuthorsCount.call(),
                    "not initialized"
                )
            })
            it("getInfo() reverts", async () => {
                await expectRevert(
                    prototype.getInfo.call(),
                    "not initialized"
                )
            })
            it("getPlayerInfo(0) reverts", async () => {
                await expectRevert(
                    prototype.getPlayerInfo.call(0),
                    "not initialized"
                )
            })
            it("getWalletInfo(curator) reverts", async () => {
                await expectRevert(
                    prototype.getWalletInfo.call(curator),
                    "not initialized"
                )
            })
            it("pixelsOf(prototype) reverts", async () => {
                await expectRevert(
                    prototype.pixelsOf.call(prototype.address),
                    "not initialized"
                )
            })
            it("totalPixels() reverts", async () => {
                await expectRevert(
                    prototype.totalPixels.call(),
                    "not initialized"
                )
            })
        })
        context("IWittyPixelsTokenVaultAuction", async () => {
            it("auctioning() reverts", async() => {
                await expectRevert(
                    prototype.auctioning.call(),
                    "not initialized"
                )
            })
            it("getPrice() reverts", async () => {
                await expectRevert(
                    prototype.getPrice.call(),
                    "not initialized"
                )
            })
            it("getAuctionSettings() reverts", async () => {
                await expectRevert(
                    prototype.getAuctionSettings.call(),
                    "not initialized"
                )
            })
            it("getAuctionType() returns expected value", async () => {
                assert.equal(
                    await prototype.getAuctionType.call(),
                    "0x6cc10588"
                )
            })
            it("setAuctionSettings(..) from master address reverts", async () => {
                var deltaPriceBN = "0x" + utils.padLeft((new BN(settings.core.events[0].auction.deltaPrice)).toString(16), "0", 64)
                var reservePriceBN = "0x" + utils.padLeft((new BN(settings.core.events[0].auction.reservePrice)).toString(16), "0", 64)
                var startingPriceBN = "0x" + utils.padLeft((new BN(settings.core.events[0].auction.startingPrice)).toString(16), "0", 64)
                await expectRevert(
                    prototype.setAuctionSettings(
                        web3.eth.abi.encodeParameter(
                            "uint256[5]", [
                                deltaPriceBN,
                                settings.core.events[0].auction.deltaSeconds,
                                reservePriceBN,
                                startingPriceBN,
                                settings.core.events[0].auction.startingTs,
                            ]
                        ),
                        { from: master }
                    ),
                    "not the curator"
                )
            })
        })
        context("IWittyPixelsTokenVaultAuctionDutch", async () => {
            it("acquire() paying 50 ETH reverts", async() => {
                await expectRevert(
                    prototype.acquire({ from: stranger, value: 50 * 10 ** 18 }),
                    "not initialized"
                )
            })
            it("getNextPriceTimestamp() reverts", async () => {
                await expectRevert(
                    prototype.getNextPriceTimestamp.call(),
                    "not initialized"
                )
            })
        })
        context("ITokenVault", async () => {
            it("curator() reverts", async() => {
                await expectRevert(
                    prototype.curator.call(),
                    "not initialized"
                )
            })
            it("acquired() reverts", async () => {
                await expectRevert(
                    prototype.acquired.call(),
                    "not initialized"
                )
            })
        })
    })
    
    context("Token proxy address as a WitnetProxy", async () => {
        
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
                                // [ "deadbeef...", "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB", 500, 174, 1000, 2345, 345, 4321]
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
                            "0x88784064616132306130343361306432393163326665326665353138643335623664343731313336333231643736306532396435643438656465626135623763356339601901f418ae1901f4190929187c193039",
                                // [ "daa20a043a0d291c2fe2fe518d35b6d471136321d760e29d5d48edeba5b7c5c9", "", 500, 174, 500, 2345, 124, 12345]
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
                        // console.log("tokenVault =>", logs[0].args.tokenVault)
                        tokenVault = await WittyPixelsTokenVault.at(logs[0].args.tokenVault)
                        // console.log("tokenVault =>", tokenVault.address)
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
                    assert.equal(
                        metadata.theStats.authorshipsRoot,
                        "0xdaa20a043a0d291c2fe2fe518d35b6d471136321d760e29d5d48edeba5b7c5c9"
                    )
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
                    var price = await tokenVault.getPrice.call()                    
                    var nextPriceTimestamp = await tokenVault.getNextPriceTimestamp.call()
                    var info = await tokenVault.getInfo.call()
                    var authorsCount = await tokenVault.getAuthorsCount.call()
                    var jackpotsCount = await tokenVault.getJackpotsCount.call()
                    var randomized = await tokenVault.randomized.call()
                    var auctioning = await tokenVault.auctioning.call()
                    await tokenVault.getAuctionSettings.call()                    
                    await tokenVault.settings.call()                    
                    assert.equal(cloned, true, "not cloned")
                    assert.equal(initialized, true, "not initialized")
                    assert.equal(self, prototype.address, "unexpected self")
                    assert.equal(symbol, settings.core.collection.symbol, "bad symbol")
                    assert.equal(tokenCurator, curator, "bad curator")
                    assert.equal(totalPixels.toString(), "174", "bad total pixels")
                    assert.equal(totalSupply.toString(), "174000000000000000000", "bad total supply")
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
            var finalPrice
            context("On 'Awaiting' status:", async () => {
                before(async () => {
                    info = await tokenVault.getInfo.call()
                    if (info.status.toString() !== "0") {
                        console.error("tokenVault: not in 'Awaiting' status")
                        process.exit(1)
                    }
                })
                context("before first redemption...", async () => {
                    it("auctioning() returns false", async () => {
                        assert.equal(await tokenVault.auctioning.call(), false)
                    })
                    it("acquired() returns false", async () => {
                        assert.equal(await tokenVault.acquired.call(), false)
                    })
                    it("trying to withdraw fails", async () => {
                        await expectRevert(
                            tokenVault.withdraw({ from: curator }),
                            "not acquired yet"
                        )
                    })
                    it("getAuthorsCount() returns 0", async () => {
                        assert.equal(
                            (await tokenVault.getAuthorsCount.call()).toString(),
                            "0"
                        )
                    })
it("curator can change auction settings", async () => {
    const data = await web3.eth.abi.encodeParameter(
        "uint256[5]", [
            settings.core.events[0].auction.deltaPrice,
            30, // seconds
            settings.core.events[0].auction.reservePrice,
            settings.core.events[0].auction.startingPrice,
            Math.floor(Date.now() / 1000)
        ]
    )
    await tokenVault.setAuctionSettings(data, { from: curator })
})
                    it("stranger cannot transfer curatorship", async () => {
                        await expectRevert(
                            tokenVault.setCurator(stranger, { from: stranger }),
                            "not the curator"
                        )
                    })
                    it("current curator can transfer curatorship", async () => {
                        await tokenVault.setCurator(backendWallet.address, { from: curator })
                        assert.equal(backend, await tokenVault.curator.call())
                    })
                })
                context("playerIndex: 17", async () => {
                    it("zero balance before redemption", async () => {
                        assert(
                            await tokenVault.balanceOf(player),
                            "0"
                        )
                    })
                    it("trying to redeem bad token id with valid signature fails", async () => {
                        await expectRevert(
                            tokenVault.redeem(
                                web3.eth.abi.encodeParameter(
                                    {
                                        "TokenVaultOwnershipDeeds": {
                                            "parentToken": 'address',
                                            "parentTokenId": 'uint256',
                                            "playerAddress": 'address',
                                            "playerIndex": 'uint256',
                                            "playerPixels": 'uint256',
                                            "playerPixelsProof": 'bytes32[]',
                                            "signature": 'bytes',
                                        }
                                    }, {
                                        parentToken: token.address,
                                        parentTokenId: "0",  // bad token id
                                        playerAddress: player,
                                        playerIndex: "17",
                                        playerPixels: "23", // such a big lie !
                                        playerPixelsProof: [
                                            "0x20ea3f905c06089a25c77876ced137bb6b51042bd7f1cff5aa1f9eb2851b0d90",
                                            "0x306df6fb2caa2b338dc21474c97d7dd9d36d2842dee9a92642799ecb27faf1d6",
                                            "0xde31a920dbdd1f015b2a842f0275dc8dec6a82ff94d9b796a36f23c64a3c8332",
                                        ],
                                        signature: "0x48f827480b88e042b3e82411ed1ccb54844a78585cd05aee2b831c662f167f6755059bb231d0d6070dd5ad8a7a28518fd01562064f8feba5a984e172d38be49a1c"
                                    },
                                ), { from: player }
                            ),
                            "unknown token"
                        )
                    })
                    it("trying to redeem true player score with invalid signature fails", async () => {
                        await expectRevert(
                            tokenVault.redeem(
                                web3.eth.abi.encodeParameter(
                                    {
                                        "TokenVaultOwnershipDeeds": {
                                            "parentToken": 'address',
                                            "parentTokenId": 'uint256',
                                            "playerAddress": 'address',
                                            "playerIndex": 'uint256',
                                            "playerPixels": 'uint256',
                                            "playerPixelsProof": 'bytes32[]',
                                            "signature": 'bytes',
                                        }
                                    }, {
                                        parentToken: token.address,
                                        parentTokenId: "1",
                                        playerAddress: player,
                                        playerIndex: "17", 
                                        playerPixels: "23",
                                        playerPixelsProof: [
                                            "0x20ea3f905c06089a25c77876ced137bb6b51042bd7f1cff5aa1f9eb2851b0d90",
                                            "0x306df6fb2caa2b338dc21474c97d7dd9d36d2842dee9a92642799ecb27faf1d6",
                                            "0xde31a920dbdd1f015b2a842f0275dc8dec6a82ff94d9b796a36f23c64a3c8332",
                                        ],
                                        signature: "0x48f827480b88e042b3e82411ed1ccb54844a78585cd05aee2b831c662f167f6755059bb231d0d6070dd5ad8a7a28518fd01562064f8feba5a984e172d38be49a1c"
                                    },
                                ), { from: player }
                            ),
                            "bad signature"
                        )
                    })
                    it("trying to redeem false player score with valid signature fails", async () => {
                        await expectRevert(
                            tokenVault.redeem(
                                web3.eth.abi.encodeParameter(
                                    {
                                        "TokenVaultOwnershipDeeds": {
                                            "parentToken": 'address',
                                            "parentTokenId": 'uint256',
                                            "playerAddress": 'address',
                                            "playerIndex": 'uint256',
                                            "playerPixels": 'uint256',
                                            "playerPixelsProof": 'bytes32[]',
                                            "signature": 'bytes',
                                        }
                                    }, {
                                        parentToken: token.address,
                                        parentTokenId: "1",
                                        playerAddress: player,
                                        playerIndex: "17",
                                        playerPixels: "333", // such a big lie !
                                        playerPixelsProof: [
                                            "0x20ea3f905c06089a25c77876ced137bb6b51042bd7f1cff5aa1f9eb2851b0d90",
                                            "0x306df6fb2caa2b338dc21474c97d7dd9d36d2842dee9a92642799ecb27faf1d6",
                                            "0xde31a920dbdd1f015b2a842f0275dc8dec6a82ff94d9b796a36f23c64a3c8332",
                                        ],
                                        signature: "0xecbc86f2a2fea1bd15168233101a952fd4365c7fa9ca6f3e9e776edd49e0ab0866d2d344995c22bb799b3bcb28f4d8f18debb9da6ba580bb938be528234a2c3f1b"
                                    },
                                ), { from: player }
                            ),
                            "false deeds"
                        )
                    })
                    it("trying to redeem true deeds with valid signature works", async () => {
                        var tx = await tokenVault.redeem(
                            web3.eth.abi.encodeParameter(
                                {
                                    "TokenVaultOwnershipDeeds": {
                                        "parentToken": 'address',
                                        "parentTokenId": 'uint256',
                                        "playerAddress": 'address',
                                        "playerIndex": 'uint256',
                                        "playerPixels": 'uint256',
                                        "playerPixelsProof": 'bytes32[]',
                                        "signature": 'bytes',
                                    }
                                }, {
                                    parentToken: token.address,
                                    parentTokenId: "1",
                                    playerAddress: player,
                                    playerIndex: "17", 
                                    playerPixels: "23",
                                    playerPixelsProof: [
                                        "0x20ea3f905c06089a25c77876ced137bb6b51042bd7f1cff5aa1f9eb2851b0d90",
                                        "0x306df6fb2caa2b338dc21474c97d7dd9d36d2842dee9a92642799ecb27faf1d6",
                                        "0xde31a920dbdd1f015b2a842f0275dc8dec6a82ff94d9b796a36f23c64a3c8332",
                                    ],
                                    signature: "0x2ab3abcfd1ef74b103c15bcbc3278cc3590df25de3f0f3f55be55332dd45fc124b009bca1f67e68ce4403f8e53cd56525c1bd14d5402e142b25e14204efa01401c"
                                },
                            ), { from: player }
                        )
                    })
                    it("trying to redeem same deeds more than once fails", async () => {
                        await expectRevert(
                            tokenVault.redeem(
                                web3.eth.abi.encodeParameter(
                                    {
                                        "TokenVaultOwnershipDeeds": {
                                            "parentToken": 'address',
                                            "parentTokenId": 'uint256',
                                            "playerAddress": 'address',
                                            "playerIndex": 'uint256',
                                            "playerPixels": 'uint256',
                                            "playerPixelsProof": 'bytes32[]',
                                            "signature": 'bytes',
                                        }
                                    }, {
                                        parentToken: token.address,
                                        parentTokenId: "1",
                                        playerAddress: player,
                                        playerIndex: "17",
                                        playerPixels: "23", 
                                        playerPixelsProof: [
                                            "0x20ea3f905c06089a25c77876ced137bb6b51042bd7f1cff5aa1f9eb2851b0d90",
                                            "0x306df6fb2caa2b338dc21474c97d7dd9d36d2842dee9a92642799ecb27faf1d6",
                                            "0xde31a920dbdd1f015b2a842f0275dc8dec6a82ff94d9b796a36f23c64a3c8332",
                                        ],
                                        signature: "0x2ab3abcfd1ef74b103c15bcbc3278cc3590df25de3f0f3f55be55332dd45fc124b009bca1f67e68ce4403f8e53cd56525c1bd14d5402e142b25e14204efa01401c"
                                    },
                                ), { from: player }
                            ),
                            "already redeemed"
                        )
                    })
                    it("player's balance after redemption matches expected value", async () => {
                        var balanceOfPlayer = await tokenVault.balanceOf(player)
                        assert.equal(balanceOfPlayer.toString(), "23000000000000000000")
                    })
                    it("redeemed player can transfer partial balance to non-player addresses", async () => {
                        await tokenVault.transfer(stranger, "1000000000000000000", { from: player })
                        var balanceOfStranger = await tokenVault.balanceOf(stranger)
                        var balanceOfPlayer = await tokenVault.balanceOf(player)
                        assert.equal(balanceOfStranger.toString(), "1000000000000000000")
                        assert.equal(balanceOfPlayer.toString(), "22000000000000000000")
                    })
                    it("souldbound pixels after redemption and transfer matches expected value", async () => {
                        var pixelsOf17 = await tokenVault.pixelsOf(player)
                        assert.equal(pixelsOf17.toString(), "23")
                    })
                    it("token owners cannot withdraw", async () => {
                        await expectRevert(
                            tokenVault.withdraw({ from: player }),
                            "not acquired yet"
                        )
                        await expectRevert(
                            tokenVault.withdraw({ from: stranger }),
                            "not acquired yet"
                        )
                    })
                    it("getAuthorsCount() returns 1", async () => {
                        assert.equal(
                            (await tokenVault.getAuthorsCount.call()).toString(),
                            "1"
                        )                        
                    })
                    it("getPlayerInfo(17) returns expected values", async () => {
                        var playerInfo = await tokenVault.getPlayerInfo.call(17)
                        assert.equal(playerInfo[0], player)
                        assert.equal(playerInfo[1], "23")
                    })
                    it("getWalletInfo(player) returns expected values", async () => {
                        var walletInfo = await tokenVault.getWalletInfo.call(player)
                        assert.equal(walletInfo[1], "0")
                        assert.equal(walletInfo[2], "23")
                    })
                })
                context("playerIndex: 3", async () => {
                    it("trying to redeem true deeds with repeated player address and valid signature works", async () => {
                        var tx = await tokenVault.redeem(
                            web3.eth.abi.encodeParameter(
                                {
                                    "TokenVaultOwnershipDeeds": {
                                        "parentToken": 'address',
                                        "parentTokenId": 'uint256',
                                        "playerAddress": 'address',
                                        "playerIndex": 'uint256',
                                        "playerPixels": 'uint256',
                                        "playerPixelsProof": 'bytes32[]',
                                        "signature": 'bytes',
                                    }
                                }, {
                                    parentToken: token.address,
                                    parentTokenId: "1",
                                    playerAddress: player,
                                    playerIndex: "3", 
                                    playerPixels: "77",
                                    playerPixelsProof: [
                                        "0x05b8ccbb9d4d8fb16ea74ce3c29a41f1b461fbdaff4714a0d9a8eb05499746bc",
                                        "0x550b876a53f6484cf42aa55bb6c8fbe2fd01da39646119ba0560d23728394567",
                                        "0xde31a920dbdd1f015b2a842f0275dc8dec6a82ff94d9b796a36f23c64a3c8332",
                                    ],
                                    signature: "0x630ae255ffa3a3dc54f193eed870a66592d7426e735e200b829517c27e0b6c3220e312bd457e8a184aad71e7595879656caa7847d5183eee3ea0645b67f052201b"
                                },
                            ), { from: player }
                        )
                    })
                    it("player's balance after redemption matches expected value", async () => {
                        var balanceOfPlayer = await tokenVault.balanceOf(player)
                        assert.equal(balanceOfPlayer.toString(), "99000000000000000000")
                    })
                    it("souldbound pixels after redemption and transfer matches expected value", async () => {
                        var pixelsOfPlayer = await tokenVault.pixelsOf(player)
                        assert.equal(pixelsOfPlayer.toString(), "100")
                    })
                    it("getAuthorsCount() returns 1", async () => {
                        assert.equal(
                            (await tokenVault.getAuthorsCount.call()).toString(),
                            "1"
                        )                        
                    })
                    it("getPlayerInfo(17) returns expected values", async () => {
                        var playerInfo = await tokenVault.getPlayerInfo.call(17)
                        assert.equal(playerInfo[0], player)
                        assert.equal(playerInfo[1], "23")
                    })
                    it("getPlayerInfo(3) returns expected values", async () => {
                        var playerInfo = await tokenVault.getPlayerInfo.call(17)
                        assert.equal(playerInfo[0], player)
                        assert.equal(playerInfo[1], "23")
                    })
                    it("getWalletInfo(player) returns expected values", async () => {
                        var walletInfo = await tokenVault.getWalletInfo.call(player)
                        assert.equal(walletInfo[1], "0")
                        assert.equal(walletInfo[2], "100")
                    })
                })
                context("after some redemptions...", async () => {
                    it.skip("getAuctionSettings() returns expected values", async () => {
                        const raw = await tokenVault.getAuctionSettings.call()
                        const params = web3.eth.abi.decodeParameter("uint256[5]", raw)
                        assert.equal(params[1], settings.core.events[0].auction.deltaSeconds.toString())
                        assert.equal(params[3], settings.core.events[0].auction.startingPrice)
                    })
                    it("stranger cannot change auction settings", async () =>{
                        const data = await web3.eth.abi.encodeParameter(
                            "uint256[5]", [
                                settings.core.events[0].auction.deltaPrice,
                                30, // seconds
                                settings.core.events[0].auction.reservePrice,
                                settings.core.events[0].auction.startingPrice,
                                Math.floor(Date.now() / 1000)
                            ]
                        )
                        await expectRevert(
                            tokenVault.setAuctionSettings(data, { from: stranger }),
                            "not the curator"
                        )
                    })
                    it.skip("curator can change auction settings", async () => {
                        const data = await web3.eth.abi.encodeParameter(
                            "uint256[5]", [
                                settings.core.events[0].auction.deltaPrice,
                                30, // seconds
                                settings.core.events[0].auction.reservePrice,
                                settings.core.events[0].auction.startingPrice,
                                Math.floor(Date.now() / 1000)
                            ]
                        )
                        await tokenVault.setAuctionSettings(data, { from: curator })
                    })
                })
            })
            context("On 'Auctioning' status:", async () => {
                before(async () => {
                    info = await tokenVault.getInfo.call()
                    if (info.status.toString() !== "2") {
                        console.error("tokenVault: not in 'Auctioning' status")
                        process.exit(1)
                    }
                })
                context("before next redemption...", async () => {
                    it("auctioning() returns true", async () => {
                        assert.equal(await tokenVault.auctioning.call(), true)
                    })
                    it("acquired() returns false", async () => {
                        assert.equal(await tokenVault.acquired.call(), false)
                    })
                    it("trying to withdraw fails", async () => {
                        await expectRevert(
                            tokenVault.withdraw({ from: curator }),
                            "not acquired yet"
                        )
                    })
                    it("getAuthorsCount() returns 1", async () => {
                        assert.equal(
                            (await tokenVault.getAuthorsCount.call()).toString(),
                            "1"
                        )
                    })
                })
                context("playerIndex: 123", async () => {
                    it("trying to redeem true deeds refering new player address from stranger address but valid signature works", async () => {
                        var tx = await tokenVault.redeem(
                            web3.eth.abi.encodeParameter(
                                {
                                    "TokenVaultOwnershipDeeds": {
                                        "parentToken": 'address',
                                        "parentTokenId": 'uint256',
                                        "playerAddress": 'address',
                                        "playerIndex": 'uint256',
                                        "playerPixels": 'uint256',
                                        "playerPixelsProof": 'bytes32[]',
                                        "signature": 'bytes',
                                    }
                                }, {
                                    parentToken: token.address,
                                    parentTokenId: "1",
                                    playerAddress: player2,
                                    playerIndex: "123", 
                                    playerPixels: "0",
                                    playerPixelsProof: [
                                        '0x44246914b6905c3d48b4e57781e66199b274c84c8a434a8fc9c58d26482e20ad',
                                    ],
                                    signature: "0xc071155f9753b48b2275f22c1207cae6f837de81662f7e6a81f25b4de91aa474026ae5fd82c123bbcdd224de0ccb00290c5f7250e3223f88c5df530c6d8157fe1c"
                                },
                            ), { from: stranger }
                        )
                    })
                    it("player's balance after redemption matches expected value", async () => {
                        var balanceOfPlayer = await tokenVault.balanceOf(player2)
                        assert.equal(balanceOfPlayer.toString(), "0")
                    })
                    it("souldbound pixels after redemption and transfer matches expected value", async () => {
                        var pixelsOfPlayer2 = await tokenVault.pixelsOf(player2)
                        assert.equal(pixelsOfPlayer2.toString(), "0")
                    })
                    it("getAuthorsCount() after redeeming new player with no pixels now returns 2", async () => {
                        assert.equal(
                            (await tokenVault.getAuthorsCount.call()).toString(),
                            "2"
                        )                        
                    })
                    it("getPlayerInfo(123) returns expected values", async () => {
                        var playerInfo = await tokenVault.getPlayerInfo.call(123)
                        assert.equal(playerInfo[0], player2)
                        assert.equal(playerInfo[1], "0")
                    })
                    it("getWalletInfo(player2) returns expected values", async () => {
                        var walletInfo = await tokenVault.getWalletInfo.call(player2)
                        assert.equal(walletInfo[1].toString(), "0")
                        assert.equal(walletInfo[2].toString(), "0")
                    })
                })
                context("auction interactions...", async () => {
                    it("getPrice() returns some value greater than zero", async () => {
                        finalPrice = await tokenVault.getPrice.call()
                        assert.notEqual(finalPrice.toString(), "0")
                    })
                    it("getNextPriceTimestamp() returns some value greater than zero", async () => {
                        assert.notEqual((await tokenVault.getNextPriceTimestamp.call()).toString(), "0")
                    })
                    it("trying to acquire by paying less than required price fails", async () => {
                        await expectRevert(
                            tokenVault.acquire({ from: patron, value: 10 ** 17 }),
                            "insufficient value"
                        )
                    })
                    it("trying to acquire by paying double the required price works, but only actual price is paid", async () => {
                        const beforeBalance = await web3.eth.getBalance(patron)
                        await tokenVault.acquire({ from: patron, value: (finalPrice * 2).toString() })
                        const afterBalance = await web3.eth.getBalance(patron)
                        assert(beforeBalance - afterBalance < (finalPrice * 2))
                    })
                })
            })
            context("On 'Acquired' status:", async () => {
                before(async () => {
                    info = await tokenVault.getInfo.call()
                    if (info.status.toString() !== "3") {
                        console.error("tokenVault: could not reach 'Acquired' status")
                        process.exit(1)
                    }
                })
                context("before next redemption...", async () => {
                    it("auctioning() returns false", async () => {
                        assert.equal(await tokenVault.auctioning.call(), false)
                    })
                    it("acquired() returns true", async () => {
                        assert.equal(await tokenVault.acquired.call(), true)
                    })
                    it("getAuthorsCount() returns 2", async () => {
                        assert.equal(
                            (await tokenVault.getAuthorsCount.call()).toString(),
                            "2"
                        )
                    })
                    it("ownership of NFT token #1 has been transferred to actual buyer", async () => {
                        assert.equal(await token.ownerOf.call(1), patron)
                        assert.equal(await token.getTokenStatusString.call(1), "Acquired")
                    })
                })
                context("playerIndex: 521", async () => {
                    it("trying to redeem true deeds refering new player address from stranger address but valid signature works", async () => {
                        var tx = await tokenVault.redeem(
                            web3.eth.abi.encodeParameter(
                                {
                                    "TokenVaultOwnershipDeeds": {
                                        "parentToken": 'address',
                                        "parentTokenId": 'uint256',
                                        "playerAddress": 'address',
                                        "playerIndex": 'uint256',
                                        "playerPixels": 'uint256',
                                        "playerPixelsProof": 'bytes32[]',
                                        "signature": 'bytes',
                                    }
                                }, {
                                    parentToken: token.address,
                                    parentTokenId: "1",
                                    playerAddress: player2,
                                    playerIndex: "521", 
                                    playerPixels: "69",
                                    playerPixelsProof: [
                                        '0x989fb179f4b9e7c79597668c23db03a7622f64e76736a9fb45d5a6c8c3eef33d',
                                        '0x306df6fb2caa2b338dc21474c97d7dd9d36d2842dee9a92642799ecb27faf1d6',
                                        '0xde31a920dbdd1f015b2a842f0275dc8dec6a82ff94d9b796a36f23c64a3c8332',
                                    ],
                                    signature: "0x4fc807a545d69e33e14cda4af4cb2ffc68fbea783a525295a62b11d03d19092a50b5552e354d23e162f0ceb3685a9e8d4aa108656e97a8415102923ac09342a91b"
                                },
                            ), { from: player2 }
                        )
                    })
                    it("player's balance after redemption matches expected value", async () => {
                        var balanceOfPlayer2 = await tokenVault.balanceOf(player2)
                        assert.equal(balanceOfPlayer2.toString(), "69000000000000000000")
                    })
                    it("souldbound pixels after redemption and transfer matches expected value", async () => {
                        var pixelsOfPlayer2 = await tokenVault.pixelsOf(player2)
                        assert.equal(pixelsOfPlayer2.toString(), "69")
                    })
                    it("getAuthorsCount() returns 2", async () => {
                        assert.equal(
                            (await tokenVault.getAuthorsCount.call()).toString(),
                            "2"
                        )                        
                    })
                    it("getPlayerInfo(521) returns expected values", async () => {
                        var playerInfo = await tokenVault.getPlayerInfo.call(521)
                        assert.equal(playerInfo[0], player2)
                        assert.equal(playerInfo[1], "69")
                    })
                    it("getWalletInfo(player2) returns expected values", async () => {
                        var walletInfo = await tokenVault.getWalletInfo.call(player2)
                        assert.notEqual(walletInfo[1], "0")
                        assert.equal(walletInfo[2], "69")
                    })
                })
                context("withdrawal interactions...", async() => {
                    it("trying to withdraw from address with no WPX balance fails", async () => {
                        await expectRevert(
                            tokenVault.withdraw({ from: curator }),
                            "no balance"
                        )
                    })
                    it("trying to withdraw from non-player address with WPX balance works", async () => {
                        const tx = await tokenVault.withdraw({ from: stranger })
                        const logs = tx.logs.filter(log => log.event === "Withdrawal")
                        assert.equal(logs[0].args.from, stranger)
                        assert.notEqual(logs[0].args.value, "0")
                    })
                    it("works if all WPX owners proceed to withdraw", async () => {
                        var tx = await tokenVault.withdraw({ from: player })
                        var logs = tx.logs.filter(log => log.event === "Withdrawal")
                        logs = tx.logs.filter(log => log.event === "Withdrawal")
                    })
                })
                context("after withdrawals...", async () => {
                    it("getAuthorsCount() returns 2", async () => {
                        assert((await tokenVault.getAuthorsCount.call()).toString(), "2")
                    })
                    it("token vault balance ends up being expected value", async () => {
                        const info = await tokenVault.getInfo.call()
                        const totalPixels = await tokenVault.totalPixels.call()
                        const missingPixels = totalPixels - info.stats.redeemedPixels
                        const expectedBalance = finalPrice * missingPixels / totalPixels;
                        const actualBalance = await web3.eth.getBalance(tokenVault.address)
                        assert.equal(actualBalance.toString().substring(0, 16), expectedBalance.toString().substring(0, 16))
                    })
                    it("legacy pixels for all players are preserved", async () => {
                        assert.equal((await tokenVault.pixelsOf.call(player)).toString(), "100")
                        assert.equal((await tokenVault.pixelsOf.call(player2)).toString(), "69")
                    })
                    it("getting range of authors works", async () => {
                        assert.equal(range.addrs.length, 2)
                        assert.equal(range.pixels.length, 2)
                        assert.equal(range.addrs[0], player)
                        assert.equal(range.addrs[1], player2)
                        assert.equal(range.pixels[0].toString(), "100")
                        assert.equal(range.pixels[1].toString(), "69")
                    })
                })
            })
        })   
    })
    
    

})