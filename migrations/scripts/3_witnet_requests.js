const fs = require("fs")

const addresses = require("../addresses")
const utils = require("../../scripts/utils")

const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoardTrustableDefault")
const WitnetRequestImageDigest = artifacts.require("WitnetRequestImageDigest")
const WitnetRequestTokenStats = artifacts.require("WitnetRequestTokenStats")


module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  var witnetAddresses
  if (!isDryRun) {
    try {
      witnetAddresses = require("witnet-solidity-bridge/migrations/witnet.addresses")[ecosystem][network]
      WitnetBytecodes.address = witnetAddresses.WitnetBytecodes
      WitnetRequestBoard.address = witnetAddresses.WitnetRequestBoard
    } catch (e) {
      console.error("Fatal: Witnet Foundation addresses were not provided!", e)
      process.exit(1)
    }
  }
  const witnetHashes = require("../witnet/hashes")
  
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestImageDigest)) {
    await deployer.deploy(
      WitnetRequestImageDigest,
      witnetAddresses?.WitnetRequestBoard || WitnetRequestBoard.address,
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
    utils.traceHeader("Skipping 'WitnetRequetImageDigest'")
    console.info("  ", "> contract address:", WitnetRequestImageDigest.address)
    console.info()
  }

  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestTokenStats)) {
    await deployer.deploy(
      WitnetRequestTokenStats,
      witnetAddresses?.WitnetRequestBoard || WitnetRequestBoard.address,
      witnetAddresses?.WitnetBytecodes || WitnetBytecodes.address,
      [ 
        witnetHashes.sources["token-stats"],
      ],
      witnetHashes.reducers["mode-no-filters"],
      witnetHashes.reducers["mode-no-filters"],
      { from, gas: 6721975 }
    )
    var contract = await WitnetRequestTokenStats.deployed()
    addresses[ecosystem][network].WitnetRequestTokenStats = contract.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    WitnetRequestTokenStats.address = addresses[ecosystem][network].WitnetRequestTokenStats
    utils.traceHeader("Skipping 'WitnetRequetTokenStats'")
    console.info("  ", "> contract address:", WitnetRequestTokenStats.address)
    console.info()
  }
}