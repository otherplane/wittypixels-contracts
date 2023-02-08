const { assert } = require("chai")
const create2 = require('eth-create2')
const fs = require("fs")
const utils = require("./utils")
const addresses = require('../migrations/addresses')

module.exports = async function () {
    var artifact = artifacts.require("WitnetProxy")
    var count = 0
    var ecosystem = "default"
    var from
    var hits = 10
    var offset = 0
    var network = "default"
    var target = "0xc0ffee"    
    process.argv.map((argv, index, args) => {
        if (argv === "--from") {
            from = args[index + 1]
        } else if (argv === "--offset") {
            offset = parseInt(args[index + 1])
        } else if (argv == "--artifact") {
            artifact = artifacts.require(args[index + 1])
        } else if (argv == "--target") {
            target = args[index + 1].toLowerCase()
            assert(web3.utils.isHexStrict(target), "--target refers invalid hex string")
        } else if (argv == "--hits") {
            hits = parseInt(args[index + 1])
        } else if (argv == "--network") {
            [ ecosystem, network ] = utils.getRealmNetworkFromString(args[index + 1].toLowerCase())
        }
    })
    try {
        from = addresses[ecosystem][network].Create2Factory
    } catch {
        console.error(`Create2Factory must have been previously deployed on network '${network}'.\n`)
        console.info("Usage:\n")
        console.info("  --artifact => Truffle artifact name (default: WitnetProxy)")
        console.info("  --hits     => Number of vanity hits to look for (default: 10)")
        console.info("  --offset   => Salt starting value minus 1 (default: 0)")
        console.info("  --network  => Network name")
        console.info("  --target   => Prefix hex number to look for (default: 0xc0ffee)")
        process.exit(1)
    }    
    const bytecode = artifact.toJSON().bytecode
    console.log("Artifact:  ", artifact.contractName)
    console.log("From:      ", from)
    console.log("Bytecode:  ", artifact.toJSON().bytecode)
    console.log("Hits:      ", hits)
    console.log("Offset:    ", offset)
    console.log("Target:    ", target)
    console.log("=".repeat(40))
    while (count < hits) {
        const salt = "0x" + utils.padLeft(offset.toString(16), "0", 32)
        const addr = create2(from, salt, bytecode)
        if (addr.toLowerCase().startsWith(target)) {
            var found = `${offset} => ${web3.utils.toChecksumAddress(addr)}`
            console.log(found)
            fs.appendFileSync(`./migrations/salts/${from.toLowerCase()}$${artifact.contractName}.tmp`, found + "\n")
            count ++
        }
        offset ++
    }
}