// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "witnet-solidity-bridge/contracts/requests/WitnetRequestTemplate.sol";
import "witnet-solidity-bridge/contracts/libs/WitnetCBOR.sol";

import "../libs/WittyPixelsLib.sol";

contract WitnetRequestTokenStats
    is
        WitnetRequestTemplate
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WittyPixelsLib for bytes;
    using WittyPixelsLib for string;

    constructor (
            WitnetRequestBoard _witnet,
            IWitnetBytecodes _registry,
            bytes32[] memory _sources,
            bytes32 _aggregator,
            bytes32 _tally
        )
        WitnetRequestTemplate(
            _witnet,
            _registry,
            _sources,
            _aggregator,
            _tally,
            WitnetV2.RadonDataTypes.Array, 
            0
        )
    {}

    function _parseWitnetResult(WitnetCBOR.CBOR memory _value)
        internal pure
        override
        returns (bytes memory _result)
    {
        WitnetCBOR.CBOR[] memory _items = _value.readArray();
        if (_items.length >= 8) {
            _result = abi.encode(WittyPixelsLib.ERC721TokenStats({
                authorshipsRoot: _items[0].readString().fromHex().toBytes32(),
                canvasDigest: _items[1].readString(),
                canvasHeight: _items[2].readUint(),
                canvasPixels: _items[3].readUint(),
                canvasWidth: _items[4].readUint(),
                totalPixels: _items[5].readUint(),
                totalPlayers: _items[6].readUint(),
                totalScans: _items[7].readUint()
            }));
        } else {
            revert("WitnetRequestTokenStats: unexpected number of response items");
        }
    }

    // web3.eth.abi.encodeParameter({"InitData": {"slaHash":'bytes32',"args":'string[][]'}}, { args: [["api.wittypixels.art/stats/1"]], slaHash: "0x738a610e267ba49e7d22c96a5f59740e88a10ba8a942047052e57dc3e69c0a64" })
}