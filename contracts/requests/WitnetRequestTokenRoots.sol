// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "witnet-solidity-bridge/contracts/requests/WitnetRequestTemplate.sol";
import "witnet-solidity-bridge/contracts/libs/WitnetCBOR.sol";

import "../libs/WittyPixels.sol";

contract WitnetRequestTokenRoots
    is
        WitnetRequestTemplate
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WittyPixels for bytes;

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
            WitnetV2.RadonDataTypes.Any, // TODO
            0
        )
    {}

    function _read(WitnetCBOR.CBOR memory _value)
        internal pure
        override
        returns (bytes memory _result)
    {
        WitnetCBOR.CBOR[] memory _items = _value.readArray();
        if (_items.length >= 3) {
            _result = abi.encode(WittyPixels.ERC721TokenRoots({
                image: _items[0].readBytes().toBytes32(),
                scores: _items[1].readBytes().toBytes32(),
                stats: _items[2].readBytes().toBytes32()
            }));
        }
    }
}