// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./WittyPixels.sol";

import "witnet-solidity-bridge/contracts/WitnetRequestBoard.sol";
import "witnet-solidity-bridge/contracts/apps/WitnetRequestFactory.sol";
import "witnet-solidity-bridge/contracts/libs/WitnetLib.sol";

/// @title  WittyPixelsLib - Deployable library containing helper methods.
/// @author Otherplane Labs Ltd., 2023

library WittyPixelsLib {

    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetLib for Witnet.Result;
    using WittyPixelsLib for WitnetRequestBoard;

    /// ===============================================================================================================
    /// --- Witnet-related helper functions ---------------------------------------------------------------------------

    /// @dev Helper function for building the HTTP/GET parameterized requests
    /// @dev from which specific data requests will be created and sent
    /// @dev to the Witnet decentralized oracle every time a new token of
    /// @dev athe ERC721 collection is minted.
    function buildHttpRequestTemplates(WitnetRequestFactory factory)
        public
        returns (
            WitnetRequestTemplate imageDigestRequestTemplate,
            WitnetRequestTemplate valuesArrayRequestTemplate
        )
    {
        IWitnetBytecodes registry = factory.registry();
        
        bytes32 httpGetImageDigest;
        bytes32 httpGetValuesArray;
        bytes32 reducerModeNoFilters;

        /// Verify that need witnet radon artifacts are actually valid and known by the factory:
        {
            httpGetImageDigest = registry.verifyDataSource(
                /* requestMethod */    WitnetV2.DataRequestMethods.HttpGet,
                /* requestSchema */    "",
                /* requestAuthority */ "\\0\\",         // => will be substituted w/ WittyPixelsLib.baseURI() on next mint
                /* requestPath */      "image/\\1\\",   // => will by substituted w/ tokenId on next mint
                /* requestQuery */     "digest=sha-256",
                /* requestBody */      "",
                /* requestHeader */    new string[2][](0),
                /* requestScript */    hex"80"
                                       // <= WitnetScript([ Witnet.TYPES.STRING ])
            );
            httpGetValuesArray = registry.verifyDataSource(
                /* requestMethod    */ WitnetV2.DataRequestMethods.HttpGet,
                /* requestSchema    */ "",
                /* requestAuthority */ "\\0\\",         // => will be substituted w/ WittyPixelsLib.baseURI() on every new mint
                /* requestPath      */ "stats/\\1\\",   // => will by substituted w/ tokenId on next mint
                /* requestQuery     */ "",
                /* requestBody      */ "",
                /* requestHeader    */ new string[2][](0),
                /* requestScript    */ hex"8218771869"
                                       // <= WitnetScript([ Witnet.TYPES.STRING ]).parseJSONMap().valuesAsArray()
            );
            reducerModeNoFilters = registry.verifyRadonReducer(
                WitnetV2.RadonReducer({
                    opcode: WitnetV2.RadonReducerOpcodes.Mode,
                    filters: new WitnetV2.RadonFilter[](0),
                    script: hex""
                })
            );
        }
        /// Use WitnetRequestFactory for building actual witnet request templates
        /// that will be parameterized w/ specific SLA valus on every new mint:  
        {
            bytes32[] memory retrievals = new bytes32[](1);
            {
                retrievals[0] = httpGetImageDigest;
                imageDigestRequestTemplate = factory.buildRequestTemplate(
                    /* retrieval templates */ retrievals,
                    /* aggregation reducer */ reducerModeNoFilters,
                    /* witnessing reducer  */ reducerModeNoFilters,
                    /* (reserved) */ 0
                );
            }
            {
                retrievals[0] = httpGetValuesArray;
                valuesArrayRequestTemplate = factory.buildRequestTemplate(
                    /* retrieval templates */ retrievals,
                    /* aggregation reducer */ reducerModeNoFilters,
                    /* witnessing reducer  */ reducerModeNoFilters,
                    /* (reserved) */ 0
                );
            }
        }
    }

    /// @notice Checks availability of Witnet responses to http/data queries, trying
    /// @notice to deserialize Witnet results into valid token metadata.
    /// @notice into a Solidity string.
    /// @dev Reverts should any of the http/requests failed, or if not able to deserialize result data.
    function fetchWitnetResults(
            WittyPixels.TokenStorage storage self, 
            WitnetRequestBoard witnet, 
            uint256 tokenId
        )
        public
    {
        WittyPixels.ERC721Token storage __token = self.items[tokenId];
        WittyPixels.ERC721TokenWitnetQueries storage __witnetQueries = self.tokenWitnetQueries[tokenId];
        // Revert if any of the witnet queries was not yet solved
        {
            if (
                !witnet.checkResultAvailability(__witnetQueries.imageDigestId)
                    || !witnet.checkResultAvailability(__witnetQueries.tokenStatsId)
            ) {
                revert("awaiting response from Witnet");
            }
        }
        Witnet.Response memory _witnetResponse; Witnet.Result memory _witnetResult;
        // Try to read response to 'image-digest' query, 
        // while freeing some storage from the Witnet Request Board:
        {
            _witnetResponse = witnet.fetchResponse(__witnetQueries.imageDigestId);
            _witnetResult = WitnetLib.resultFromCborBytes(_witnetResponse.cborBytes);
            {
                // Revert if the Witnet query failed:
                require(
                    _witnetResult.success,
                    "'image-digest' query failed"
                );
                // Revert if the Witnet response was previous to when minting started:
                require(
                    _witnetResponse.timestamp >= __token.birthTs,
                    "anachronic 'image-digest' result"
                );
            }
            // Deserialize http/response to 'image-digest':
            __token.imageDigest = _witnetResult.value.readString();
            __token.imageDigestWitnetTxHash = _witnetResponse.drTxHash;
        }
        // Try to read response to 'token-stats' query, 
        // while freeing some storage from the Witnet Request Board:
        {
            _witnetResponse = witnet.fetchResponse(__witnetQueries.tokenStatsId);
            _witnetResult = WitnetLib.resultFromCborBytes(_witnetResponse.cborBytes);
            {
                // Revert if the Witnet query failed:
                require(
                    _witnetResult.success,
                    "'token-stats' query failed"
                );
                // Revert if the Witnet response was previous to when minting started:
                require(
                    _witnetResponse.timestamp >= __token.birthTs, 
                    "anachronic 'token-stats' result");
            }
            // Try to deserialize Witnet response to 'token-stats':
            __token.theStats = toERC721TokenStats(_witnetResult.value);
        }
    }

    /// @dev Check if a some previsouly posted request has been solved and reported from Witnet.
    function checkResultAvailability(
            WitnetRequestBoard witnet,
            uint256 witnetQueryId
        )
        internal view
        returns (bool)
    {
        return witnet.getQueryStatus(witnetQueryId) == Witnet.QueryStatus.Reported;
    }

    /// @dev Retrieves copy of all response data related to a previously posted request, 
    /// @dev removing the whole query from storage.
    function fetchResponse(
            WitnetRequestBoard witnet,
            uint256 witnetQueryId
        )
        internal
        returns (Witnet.Response memory)
    {
        return witnet.deleteQuery(witnetQueryId);
    }

    /// @dev Deserialize a CBOR-encoded data request result from Witnet 
    /// @dev into a WittyPixels.ERC721TokenStats structure
    function toERC721TokenStats(WitnetCBOR.CBOR memory cbor)
        internal pure
        returns (WittyPixels.ERC721TokenStats memory)
    {
        WitnetCBOR.CBOR[] memory fields = cbor.readArray();
        if (fields.length >= 7) {
            return WittyPixels.ERC721TokenStats({
                canvasHeight: fields[0].readUint(),
                canvasPixels: fields[1].readUint(),
                canvasRoot:   toBytes32(fromHex(fields[2].readString())),
                canvasWidth:  fields[3].readUint(),
                totalPixels:  fields[4].readUint(),
                totalPlayers: fields[5].readUint(),
                totalScans:   fields[6].readUint()
            });
        } else {
            revert("WittyPixelsLib: missing fields");
        }
    }
    

    /// ===============================================================================================================
    /// --- WittyPixels-related helper methods ------------------------------------------------------------------------

    /// @dev Returns JSON string containing the metadata of given tokenId
    /// @dev following an OpenSea-compatible schema.
    function toJSON(
            WittyPixels.ERC721Token memory self,
            uint256 tokenId
        )
        public pure
        returns (string memory)
    {
        string memory _name = string(abi.encodePacked(
            "\"name\": \"", self.theEvent.name, "\","
        ));
        string memory _description = string(abi.encodePacked(
            "\"description\": \"",
            _loadJsonDescription(self, tokenId),
            "\","
        ));
        string memory _externalUrl = string(abi.encodePacked(
            "\"external_url\": \"", tokenMetadataURI(tokenId, self.baseURI), "\","
        ));
        string memory _image = string(abi.encodePacked(
            "\"image\": \"", tokenImageURI(tokenId, self.baseURI), "\","
        ));
        string memory _attributes = string(abi.encodePacked(
            "\"attributes\": [",
            _loadJsonAttributes(self),
            "]"
        ));
        return string(abi.encodePacked(
            "{", _name, _description, _externalUrl, _image, _attributes, "}"
        ));
    }

    function tokenImageURI(uint256 tokenId, string memory baseURI)
        internal pure
        returns (string memory)
    {
        return string(abi.encodePacked(
            baseURI,
            "/image/",
            toString(tokenId)
        ));
    }

    function tokenMetadataURI(uint256 tokenId, string memory baseURI)
        internal pure
        returns (string memory)
    {
        return string(abi.encodePacked(
            baseURI,
            "/metadata/",
            toString(tokenId)
        ));
    }

    function tokenStatsURI(uint256 tokenId, string memory baseURI)
        internal pure
        returns (string memory)
    {
        return string(abi.encodePacked(
            baseURI,
            "/stats/",
            toString(tokenId)
        ));
    }
    
    function checkBaseURI(string memory uri)
        internal pure
        returns (string memory)
    {
        require((
            bytes(uri).length > 0
                && bytes(uri)[
                    bytes(uri).length - 1
                ] != bytes1("/")
            ), "WittyPixelsLib: bad uri"
        );
        return uri;
    }

    function fromHex(string memory s)
        internal pure
        returns (bytes memory)
    {
        bytes memory ss = bytes(s);
        assert(ss.length % 2 == 0);
        bytes memory r = new bytes(ss.length / 2);
        unchecked {
            for (uint i = 0; i < ss.length / 2; i ++) {
                r[i] = bytes1(
                    fromHexChar(uint8(ss[2 * i])) * 16
                        + fromHexChar(uint8(ss[2 * i + 1]))
                );
            }
        }
        return r;
    }

    function fromHexChar(uint8 c)
        internal pure
        returns (uint8)
    {
        if (
            bytes1(c) >= bytes1("0")
                && bytes1(c) <= bytes1("9")
        ) {
            return c - uint8(bytes1("0"));
        } else if (
            bytes1(c) >= bytes1("a")
                && bytes1(c) <= bytes1("f")
        ) {
            return 10 + c - uint8(bytes1("a"));
        } else if (
            bytes1(c) >= bytes1("A")
                && bytes1(c) <= bytes1("F")
        ) {
            return 10 + c - uint8(bytes1("A"));
        } else {
            revert("WittyPixelsLib: invalid hex");
        }
    }

    function hash(bytes32 a, bytes32 b)
        internal pure
        returns (bytes32)
    {
        return (a < b 
            ? _hash(a, b)
            : _hash(b, a)
        );
    }

    function merkle(bytes32[] memory proof, bytes32 leaf)
        internal pure
        returns (bytes32 root)
    {
        root = leaf;
        for (uint i = 0; i < proof.length; i ++) {
            root = hash(root, proof[i]);
        }
    }

    /// Recovers address from hash and signature.
    function recoverAddr(bytes32 hash_, bytes memory signature)
        internal pure
        returns (address)
    {
        if (signature.length != 65) {
            return (address(0));
        }
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return address(0);
        }
        if (v != 27 && v != 28) {
            return address(0);
        }
        return ecrecover(hash_, v, r, s);
    }   

    function slice(bytes memory src, uint offset)
        internal pure
        returns (bytes memory dest)
    {
        assert(offset < src.length);
        unchecked {
            uint srcPtr;
            uint destPtr;
            uint len = src.length - offset;
            assembly {
                srcPtr := add(src, add(32, offset))
                destPtr:= add(dest, 32)
                mstore(dest, len)
            }
            _memcpy(
                destPtr,
                srcPtr,
                len
            );
        }
    }

    function toBytes32(bytes memory _value) internal pure returns (bytes32) {
        return toFixedBytes(_value, 32);
    }

    function toFixedBytes(bytes memory _value, uint8 _numBytes)
        internal pure
        returns (bytes32 _bytes32)
    {
        assert(_numBytes <= 32);
        unchecked {
            uint _len = _value.length > _numBytes ? _numBytes : _value.length;
            for (uint _i = 0; _i < _len; _i ++) {
                _bytes32 |= bytes32(_value[_i] & 0xff) >> (_i * 8);
            }
        }
    }

    bytes16 private constant _HEX_SYMBOLS_ = "0123456789abcdef";

    /// @dev Converts a `uint256` to its ASCII `string` decimal representation.
    function toString(uint256 value)
        internal pure
        returns (string memory)
    {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _HEX_SYMBOLS_))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /// @dev Converts a `bytes32` to its hex `string` representation with no "0x" prefix.
    function toHexString(bytes32 value)
        internal pure
        returns (string memory)
    {
        bytes memory buffer = new bytes(64);
        for (uint256 i = 64; i > 0; i --) {
            buffer[i - 1] = _HEX_SYMBOLS_[uint(value) & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }


    // ================================================================================================================
    // --- WittyPixelsLib private methods ----------------------------------------------------------------------------

    function _loadJsonAttributes(WittyPixels.ERC721Token memory self)
        private pure
        returns (string memory)
    {
        string memory _eventName = string(abi.encodePacked(
            "{",
                "\"trait_type\": \"Event Name\",",
                "\"value\": \"", self.theEvent.name, "\"",
            "},"
        ));
        string memory _eventVenue = string(abi.encodePacked(
            "{",
                "\"trait_type\": \"Event Venue\",",
                "\"value\": \"", self.theEvent.venue, "\"",
            "},"
        ));
        string memory _eventStartDate = string(abi.encodePacked(
             "{",
                "\"display_type\": \"date\",",
                "\"trait_type\": \"Event Start Date\",",
                "\"value\": ", toString(self.theEvent.startTs),
            "},"
        ));
        string memory _eventEndDate = string(abi.encodePacked(
             "{",
                "\"display_type\": \"date\",",
                "\"trait_type\": \"Event End Date\",",
                "\"value\": ", toString(self.theEvent.endTs),
            "},"
        ));
        string memory _authorshipRoot = string(abi.encodePacked(
            "{",
                "\"trait_type\": \"Authorship's Root\",",
                "\"value\": \"", toHexString(self.theStats.canvasRoot), "\"",
            "},"
        ));
        
        string memory _totalPlayers = string(abi.encodePacked(
            "{", 
                "\"trait_type\": \"Total Players\",",
                "\"value\": ", toString(self.theStats.totalPlayers),
            "},"
        ));
        string memory _totalScans = string(abi.encodePacked(
            "{", 
                "\"trait_type\": \"Total Scans\",",
                "\"value\": ", toString(self.theStats.totalScans),
            "}"
        ));
        return string(abi.encodePacked(
            _eventName,
            _eventVenue,
            _eventStartDate,
            _eventEndDate,
            _authorshipRoot,
            _loadJsonCanvasAttributes(self),
            _totalPlayers,
            _totalScans
        ));
    }

    function _loadJsonCanvasAttributes(WittyPixels.ERC721Token memory self)
        private pure
        returns (string memory)
    {
        string memory _canvasDate = string(abi.encodePacked(
             "{",
                "\"display_type\": \"date\",",
                "\"trait_type\": \"Canvas Date\",",
                "\"value\": ", toString(self.birthTs),
            "},"
        ));
        string memory _canvasDigest = string(abi.encodePacked(
            "{",
                "\"trait_type\": \"Canvas Digest\",",
                "\"value\": \"", self.imageDigest, "\"",
            "},"
        ));        
        string memory _canvasHeight = string(abi.encodePacked(
             "{",
                "\"display_type\": \"number\",",
                "\"trait_type\": \"Canvas Height\",",
                "\"value\": ", toString(self.theStats.canvasHeight),
            "},"
        ));    
        string memory _canvasWidth = string(abi.encodePacked(
             "{",
                "\"display_type\": \"number\",",
                "\"trait_type\": \"Canvas Width\",",
                "\"value\": ", toString(self.theStats.canvasWidth),
            "},"
        ));
        string memory _canvasPixels = string(abi.encodePacked(
            "{", 
                "\"trait_type\": \"Canvas Pixels\",",
                "\"value\": ", toString(self.theStats.canvasPixels),
            "},"
        ));
        string memory _canvasOverpaint;
        if (
            self.theStats.totalPixels > 0
                && self.theStats.totalPixels > self.theStats.canvasPixels
        ) {
            uint _ratio = (self.theStats.totalPixels - self.theStats.canvasPixels);
            _ratio *= 10 ** 6;
            _ratio /= self.theStats.totalPixels;
            _ratio /= 10 ** 4;
            _canvasOverpaint = string(abi.encodePacked(
                "{",
                    "\"display_type\": \"boost_percentage\",",
                    "\"trait_type\": \"Canvas Overpaint\",",
                    "\"value\": ", toString(_ratio),
                "},"
            ));
        }
        return string(abi.encodePacked(
            _canvasDate,
            _canvasDigest,
            _canvasHeight,            
            _canvasWidth,
            _canvasPixels,
            _canvasOverpaint
        ));
    }

    function _loadJsonDescription(WittyPixels.ERC721Token memory self, uint256 tokenId)
        private pure
        returns (string memory)
    {
        string memory _tokenIdStr = toString(tokenId);
        string memory _totalPlayersString = toString(self.theStats.totalPlayers);
        string memory _radHashHexString = toHexString(self.tokenStatsWitnetRadHash);
        return string(abi.encodePacked(
            "WittyPixelsTM collaborative art canvas #", _tokenIdStr, " drawn by ", _totalPlayersString,
            " attendees during '<b>", self.theEvent.name, "</b>' in ", self.theEvent.venue, 
            ". This token was fractionalized and secured by the [Witnet multichain",
            " oracle](https://witnet.io). Historical WittyPixelsTM game info and",
            " authorship's root during '", self.theEvent.name, "'",
            " can be audited on [Witnet's block explorer](https://witnet.network/",
            _radHashHexString, ")."
        ));
    }

    function _hash(bytes32 a, bytes32 b)
        private pure
        returns (bytes32 value)
    {
        assembly {
            mstore(0x0, a)
            mstore(0x20, b)
            value := keccak256(0x0, 0x40)
        }
    }

    function _memcpy(
            uint _dest,
            uint _src,
            uint _len
        )
        private pure
    {
        // Copy word-length chunks while possible
        for (; _len >= 32; _len -= 32) {
            assembly {
                mstore(_dest, mload(_src))
            }
            _dest += 32;
            _src += 32;
        }
        if (_len > 0) {
            // Copy remaining bytes
            uint _mask = 256 ** (32 - _len) - 1;
            assembly {
                let _srcpart := and(mload(_src), not(_mask))
                let _destpart := and(mload(_dest), _mask)
                mstore(_dest, or(_destpart, _srcpart))
            }
        }
    }

}