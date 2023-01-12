const fs = require("fs")

const addresses = require("../addresses")
const utils = require("../../scripts/utils")

const WitnetRequestImageDigest = artifacts.require("WitnetRequestImageDigest")
const WitnetRequestTokenRoots = artifacts.require("WitnetRequestTokenRoots")

const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetEncodingLib = artifacts.require("WitnetEncodingLib")

module.exports = async function (deployer, network, [, from]) {
  if (network !== "test") {
    const isDryRun = network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
    const ecosystem = utils.getRealmNetworkFromArgs()[0]
    network = network.split("-")[0]

    if (!addresses[ecosystem]) addresses[ecosystem] = {}
    if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

    var witnetAddresses
    if (!isDryRun) {
      try {
        witnetAddresses = require("witnet-solidity-bridge/migrations/witnet.addresses")[ecosystem][network]
        WitnetBytecodes.address = witnetAddresses.WitnetBytecodes
      } catch (e) {
        console.error("Fatal: Witnet Foundation addresses were not provided!", e)
        process.exit(1)
      }
    }
    const witnetHashes = require("../witnet/hashes")
    
    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestImageDigest)) {
      await deployer.deploy(
        WitnetRequestImageDigest,
        witnetAddresses?.WitnetRequestBoard || "0xffffffffffffffffffffffffffffffffffffffff",
        witnetAddresses?.WitnetBytecodes || WitnetBytecodes.address,
        [ 
          witnetHashes.sources["image-digest"],
        ],
        witnetHashes.reducers["mode-no-filters"],
        witnetHashes.reducers["mode-no-filters"],
        { from, gas: 6721975 }
      )
      var contract = await WitnetRequestImageDigest.deployed()
      addresses[ecosystem][network].WitnetRequestImageDigest = contract.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      WitnetRequestImageDigest.address = addresses[ecosystem][network].WitnetRequestImageDigest
    }

    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestTokenRoots)) {
      await deployer.deploy(
        WitnetRequestTokenRoots,
        witnetAddresses?.WitnetRequestBoard || "0xffffffffffffffffffffffffffffffffffffffff",
        witnetAddresses?.WitnetBytecodes || WitnetBytecodes.address,
        [ 
          witnetHashes.sources["token-roots"],
        ],
        witnetHashes.reducers["mode-no-filters"],
        witnetHashes.reducers["mode-no-filters"],
        { from, gas: 6721975 }
      )
      var contract = await WitnetRequestTokenRoots.deployed()
      addresses[ecosystem][network].WitnetRequestTokenRoots = contract.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      WitnetRequestTokenRoots.address = addresses[ecosystem][network].WitnetRequestTokenRoots
    }
  }
}