const fs = require("fs")

const addresses = require("../addresses")
const utils = require("../../scripts/utils")

const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetEncodingLib = artifacts.require("WitnetEncodingLib")
const WitnetLib = artifacts.require("WitnetLib")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoardTrustableDefault")

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
  } else {
    await deployer.deploy(WitnetEncodingLib, { from })
    await deployer.link(WitnetEncodingLib, WitnetBytecodes)
    await deployer.deploy(WitnetBytecodes, true, utils.fromAscii(network), { from, gas: 6721975 })
    await deployer.deploy(WitnetLib, { from })
    await deployer.link(WitnetLib, WitnetRequestBoard)
    await deployer.deploy(WitnetRequestBoard, true, utils.fromAscii(network), 135000, { from, gas: 6721975 })
  }

  const witnetHashes = require("../witnet/hashes"); if (!witnetHashes.sources) witnetHashes.sources = {}
  const witnetRegistry = await WitnetBytecodes.deployed()
  const witnetSources = require("../witnet/sources.js")
  
  for (const key in witnetSources) {      
    const source = witnetSources[key]
    const header = `Verifying Witnet data source '${key}'...`
    console.info()
    console.info("  ", header)
    console.info("  ", "-".repeat(header.length))
    if (source.requestSchema) {
      console.info(`   > Request schema:      ${source.requestSchema}`)
    }
    console.info(`   > Request method:      ${getRequestMethodString(await source.requestMethod)}`)
    console.info(`   > Request authority:   ${source.requestAuthority}`)
    if (source.requestPath)  {
      console.info(`   > Request path:        ${source.requestPath}`)
    }
    if (source.requestQuery) {
      console.info(`   > Request query:       ${source.requestQuery}`)
    }
    if (source.requestBody) {
      console.info(`   > Request body:        ${source.requestBody}`)
    }
    if (source.requestHeaders) {
      console.info(`   > Request headers:     ${source.requestHeaders}`)
    }
    console.info(`   > Request script:      ${source.requestScript || "0x80"}`)
    // get actual hash for this data source
    var hash = await witnetRegistry.verifyDataSource.call(
      await source.requestMethod || 1,
      source.requestSchema || "",
      source.requestAuthority,
      source.requestPath || "",
      source.requestQuery || "",
      source.requestBody || "",
      source.requestHeaders || [],
      source.requestScript || "0x80",
      { from }
    )
    // register the data source if it was not yet registered
    if (dataSourceNotYetRegistered(witnetRegistry, hash) === true) {
      const tx = await witnetRegistry.verifyDataSource(
        await source.requestMethod || 1,
        source.requestSchema || "",
        source.requestAuthority,
        source.requestPath || "",
        source.requestQuery || "",
        source.requestBody || "",
        source.requestHeaders || [],
        source.requestScript || "0x80",
        { from }
      )
      console.info(`   > transaction hash:    ${tx.receipt.transactionHash}`)
      console.info(`   > gas used:            ${tx.receipt.gasUsed}`)
      hash = tx.logs[tx.logs.length - 1].args.hash
      console.info(`   > data source hash:    ${hash}`)
    } else {
      console.info(`   $ data source hash:    ${hash}`)
    }
    witnetHashes.sources[key] = hash      
    utils.saveHashes(witnetHashes)
  }

  if (!witnetHashes.reducers) witnetHashes.reducers = {}
  const witnetReducers = require("../witnet/reducers.js")
  for (const key in witnetReducers) {    
    const reducer = witnetReducers[key]
    const header = `Verifying Witnet radon reducer '${key}'...`
    console.info()
    console.info("  ", header)
    console.info("  ", "-".repeat(header.length))
    console.info(`   > Reducer opcode:      ${reducer.opcode}`)
    console.info(`   > Reducer filters:     ${reducer.filters.length > 0 ? reducer.filters : '(no filters)'}`)
    // get actual hash for this radon reducer
    var hash = await witnetRegistry.verifyRadonReducer.call([
      reducer.opcode,
        reducer.filters,
        reducer.script,
      ],
      { from }
    )
    // register the reducer was not yet registered
    if (radonReducerNotYetRegistered(witnetRegistry, hash) === true) {
      const tx = await witnetRegistry.verifyRadonReducer([
          reducer.opcode,
          reducer.filters,
          reducer.script,
        ],
        { from }
      )
      console.info(`   > transaction hash:    ${tx.receipt.transactionHash}`)
      console.info(`   > gas used:            ${tx.receipt.gasUsed}`)
      hash = tx.logs[tx.logs.length - 1].args.hash
      console.info(`   > radon reducer hash:  ${hash}`)
    } else {
      console.info(`   $ radon reducer hash:  ${hash}`)
    }
    witnetHashes.reducers[key] = hash
    utils.saveHashes(witnetHashes)
  }
  console.info()
}

function getRequestMethodString(method) {
  if (method == 0) {
    return "UNKNOWN"
  } else if (method == 1 || !method) {
    return "HTTP/GET"
  } else if (method == 2) {
    return "RNG"
  } else if (method == 3) {
    return "HTTP/POST"
  } else {
    return method.toString()
  }
}

async function dataSourceNotYetRegistered(registry, hash) {
  try {
    await registry.lookupDataSource.call(hash, { from: '' })
    return false
  } catch {
    return true
  }
}

async function radonReducerNotYetRegistered(registry, hash) {
  try {
    await registry.lookupRadonReducer.call(hash, { from: '' })
    return false
  } catch {
    return true
  }
}