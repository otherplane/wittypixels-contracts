const addresses = require("../addresses")
const utils = require("../../scripts/utils")

const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetEncodingLib = artifacts.require("WitnetEncodingLib")
const WitnetLib = artifacts.require("WitnetLib")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")
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
      WitnetBytecodes.address = witnetAddresses.WitnetBytecodes
      WitnetRequestBoard.address = witnetAddresses.WitnetRequestBoard
      WitnetRequestFactory.address = witnetAddresses.WitnetRequestFactory

      utils.traceHeader("Witnet artifacts:")
      console.info("  ", "> WitnetBytecodes:      ", WitnetBytecodes.address)
      console.info("  ", "> WitnetRequestBoard:   ", WitnetRequestBoard.address)
      console.info("  ", "> WitnetRequestFactory: ", WitnetRequestFactory.address)
    } catch (e) {
      console.error("Fatal: Witnet Foundation addresses were not provided!", e)
      process.exit(1)
    }
  } else {
    const WitnetRequestBoardTrustableDefault = artifacts.require('WitnetRequestBoardTrustableDefault')
    await deployer.deploy(WitnetEncodingLib, { from })
    await deployer.link(WitnetEncodingLib, WitnetBytecodes)
    await deployer.deploy(WitnetBytecodes, true, utils.fromAscii(network), { from, gas: 6721975 })
    await deployer.deploy(WitnetLib, { from })
    await deployer.link(WitnetLib, WitnetRequestBoardTrustableDefault)
    await deployer.deploy(WitnetRequestBoardTrustableDefault, true, utils.fromAscii(network), 135000, { from, gas: 6721975 })
    await deployer.deploy(
      WitnetRequestFactory,
      WitnetBytecodes.address,
      true,
      utils.fromAscii(network),
      { from, gas: 6721975 }
    )
    WitnetRequestBoard.address = WitnetRequestBoardTrustableDefault.address
  }
}