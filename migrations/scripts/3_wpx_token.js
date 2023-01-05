const fs = require("fs")
const { merge } = require("lodash")

const addresses = require("../addresses")
const package = require ("../../package")
const settings = require("../settings")
const utils = require("../../scripts/utils")

const WitnetProxy = artifacts.require("WitnetProxy")
const WittyPixelsToken = artifacts.require("WittyPixelsToken")

const WitnetRequestImageDigest = artifacts.require("WitnetRequestImageDigest")
const WitnetRequestTokenRoots = artifacts.require("WitnetRequestTokenRoots")

module.exports = async function (deployer, network, accounts) {
  if (network !== "test") {
    const isDryRun = network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
    const ecosystem = utils.getRealmNetworkFromArgs()[0]
    network = network.split("-")[0]

    if (!addresses[ecosystem]) addresses[ecosystem] = {}
    if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

    var proxy
    if (utils.isNullAddress(addresses[ecosystem][network]?.WittyPixelsTokenProxy)) {
      await deployer.deploy(WitnetProxy)
      proxy = await WitnetProxy.deployed()
      addresses[ecosystem][network].WittyPixelsTokenProxy = proxy.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      proxy = await WitnetProxy.at(addresses[ecosystem][network].WittyPixelsTokenProxy)
    }

    var token
    if (utils.isNullAddress(addresses[ecosystem][network]?.WittyPixelsToken)) {
      await deployer.deploy(
        WittyPixelsToken,
        WitnetRequestImageDigest.address,
        WitnetRequestTokenRoots.address,
        settings.core.collection.upgradable,
        utils.fromAscii(package.version)
      )
      token = await WittyPixelsToken.deployed()
      addresses[ecosystem][network].WittyPixelsToken = token.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      token = await WittyPixelsToken.at(addresses[ecosystem][network].WittyPixelsToken)
    }

    var implementation = await proxy.implementation()
    if (implementation.toLowerCase() !== token.address.toLowerCase()) {
      const header = `Upgrading WittyPixelsTokenProxy to v${await token.version()}...`
      console.info()
      console.info("  ", header)
      console.info("  ", "-".repeat(header.length))
      console.info()
      console.info("   > old implementation:", implementation)
      console.info("   > new implementation:", token.address)
      if (implementation === "0x0000000000000000000000000000000000000000" ) {
        console.info("   > new token base uri:", settings.core.collection.baseURI)
      }      
      const tx = await proxy.upgradeTo(
        token.address,           
        web3.eth.abi.encodeParameter(
          "string[3]", [
            settings.core.collection.baseURI,
            settings.core.collection.name,
            settings.core.collection.symbol
          ]
        )
      )
      console.info("   => transaction hash :", tx.receipt.transactionHash)
      console.info("   => transaction gas  :", tx.receipt.gasUsed)
    }
  }
}