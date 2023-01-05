const fs = require("fs")
const { merge } = require("lodash")

const addresses = require("../addresses")
const package = require ("../../package")
const settings = require("../settings")
const utils = require("../../scripts/utils")

const WitnetRandomness = artifacts.require("WitnetRandomness")
const WitnetRandomnessMock = artifacts.require("WitnetRandomnessMock")

const WittyPixelsToken = artifacts.require("WittyPixelsToken")
const WittyPixelsTokenVault = artifacts.require("WittyPixelsTokenVault")

module.exports = async function (deployer, network, accounts) {
  if (network !== "test") {
    const isDryRun = network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
    const ecosystem = utils.getRealmNetworkFromArgs()[0]
    network = network.split("-")[0]

    if (!addresses[ecosystem]) addresses[ecosystem] = {}
    if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

    var witnetAddresses
    var randomizer
    if (!isDryRun) {
      try {
        witnetAddresses = require("witnet-solidity-bridge/migrations/witnet.addresses")[ecosystem][network]
        randomizer = await WitnetRandomness.at(witnetAddresses.WitnetRandomness)
      } catch (e) {
        console.error("Fatal: Witnet Foundation addresses were not provided!", e)
        process.exit(1)
      }
    } else {
      randomizer = await WitnetRandomnessMock.new(
        2,        // _mockRandomizeLatencyBlocks
        10 ** 15, // _mockRandomizeFee
      )
    }

    var vault
    if (utils.isNullAddress(addresses[ecosystem][network]?.WittyPixelsTokenVaultPrototype)) {
      await deployer.deploy(
        WittyPixelsTokenVault,
        randomizer.address,
        utils.fromAscii(package.version)
      )
      vault = await WittyPixelsTokenVault.deployed()
      addresses[ecosystem][network].WittyPixelsTokenVaultPrototype = vault.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      vault = await WittyPixelsTokenVault.at(addresses[ecosystem][network].WittyPixelsTokenVaultPrototype)
    }

    var token = await WittyPixelsToken.at(addresses[ecosystem][network].WittyPixelsTokenProxy)
    var prototype = await token.tokenVaultPrototype()
    if (protoype.toLowerCase() !== vault.address.toLowerCase()) {
      const header = `Setting WittyPixelsTokenProxy's prototype to v${await vault.version()}...`
      console.info()
      console.info("  ", header)
      console.info("  ", "-".repeat(header.length))
      console.info()
      console.info("   > old vault prototype:", prototype.address)
      console.info("   > new vault prototype:", vault.address)
      const tx = await token.setTokenVaultPrototype(vault.address)
      console.info("   => transaction hash :", tx.receipt.transactionHash)
      console.info("   => transaction gas  :", tx.receipt.gasUsed)
    }
  }
}