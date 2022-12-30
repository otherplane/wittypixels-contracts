const fs = require("fs")
const { merge } = require("lodash")

const addresses = require("../addresses")
const package = require ("../../package")
const settings = require("../settings")
const utils = require("../../scripts/utils")

const WitnetProxy = artifacts.require("WitnetProxy")
const WittyPixelsToken = artifacts.require("WittyPixelsToken")

const WitnetRequestImageDigest = artifacts.require("WitnetRequestImageDigest")
const WitnetRequestWittyPixelsMetadata = artifacts.require("WitnetRequestWittyPixelsMetadata")

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
        saveAddresses(addresses)
      }
    } else {
      proxy = await WitnetProxy.at(addresses[ecosystem][network].WittyPixelsTokenProxy)
    }

    var token
    if (utils.isNullAddress(addresses[ecosystem][network]?.WittyPixelsToken)) {
      await deployer.deploy(
        WittyPixelsToken,
        WitnetRequestImageDigest.address,
        WitnetRequestWittyPixelsMetadata.address,
        settings.core.collection.baseURI,
        settings.core.collection.upgradable,
        utils.fromAscii(package.version)
      )
      token = await WittyPixelsToken.deployed()
      addresses[ecosystem][network].WittyPixelsToken = token.address
      if (!isDryRun) {
        saveAddresses(addresses)
      }
    } else {
      token = await WittyPixelsToken.at(addresses[ecosystem][network].WittyPixelsToken)
    }

    var implementation = await proxy.implementation()
    if (implementation.toLowerCase() !== token.address.toLowerCase()) {
      console.info()
      console.info("   > WittyPixelsToken:", token.address)
      console.info("   > WittyPixelsTokenProxy:", proxy.address)
      console.info("   > WittyPixelsTokenProxy.implementation::", implementation)
      const answer = await utils.prompt(`   > Upgrade the proxy ? [y/N] `)
      if (["y", "yes"].includes(answer.toLowerCase().trim())) {
        await proxy.upgradeTo(token.address, "0x")
        console.info("   > Done.")
      } else {
        console.info("   > Not upgraded.")
      }
    }
  }
}

function saveAddresses(addrs) {
  fs.writeFileSync(
    "./migrations/addresses.json",
    JSON.stringify(addrs, null, 4),
    { flag: 'w+'}
  )
}