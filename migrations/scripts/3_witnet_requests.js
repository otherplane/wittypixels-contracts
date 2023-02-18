const fs = require("fs")

const addresses = require("../addresses")
const utils = require("../../scripts/utils")

const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetRequestFactory = artifacts.require("WitnetRequestFactory")

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
      WitnetRequestFactory.address = witnetAddresses.WitnetRequestFactory
    } catch (e) {
      console.error("Fatal: Witnet Foundation addresses were not provided!", e)
      process.exit(1)
    }
  } else {
    await deployer.deploy(
      WitnetRequestFactory,
      WitnetBytecodes.address,
      true,
      utils.fromAscii(network),
      { from, gas: 6721975 }
    )
  }

  const witnetHashes = require("../witnet/hashes"); if (!witnetHashes.rads) witnetHashes.rads = {}
  const witnetRequestFactory = await WitnetRequestFactory.at(WitnetRequestFactory.address);
  const witnetRequestTemplates = require("../witnet/templates.js")
  
  for (const key in witnetRequestTemplates) {
    const template = witnetRequestTemplates[key]
    if (isDryRun || utils.isNullAddress(addresses[ecosystem][network][key])) {
      utils.traceHeader(`Building '${key}'...`)
      console.info("  ", "> factory address: ", witnetRequestFactory.address)
      var tx = await witnetRequestFactory.buildRequestTemplate(
        template.sources,
        template.aggregator,
        template.tally,
        template?.resultDataMaxSize || 0,
        { from }
      )
      tx.logs = tx.logs.filter(log => log.event === 'WitnetRequestTemplateBuilt')
      console.info("  ", "> transaction hash:", tx.receipt.transactionHash)
      console.info("  ", "> transaction gas: ", tx.receipt.gasUsed)
      console.info("  ", "> template address:", tx.logs[0].args.template)
      addresses[ecosystem][network][key] = tx.logs[0].args.template
      utils.saveAddresses(addresses)
    } else {
      utils.traceHeader(`Skipping '${key}'`)
      console.info("  ", "> template address:", addresses[ecosystem][network][key])
    }
  }
}