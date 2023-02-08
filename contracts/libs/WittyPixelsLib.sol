// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "witnet-solidity-bridge/contracts/requests/WitnetRequestTemplate.sol";
import "../interfaces/IWittyPixelsTokenVault.sol";

library WittyPixelsLib {

    bytes16 private constant _HEX_SYMBOLS_ = "0123456789abcdef";

    struct TokenInitParams {
        string baseURI;
        string name;
        string symbol;
    }

    struct TokenStorage {
        address implementation;
        
        // --- ERC721
        string  baseURI;
        uint256 totalSupply;
        mapping (uint256 => ERC721Token) items;
        
        // --- ITokenVaultFactory
        IWittyPixelsTokenVault tokenVaultPrototype;
        uint256 totalTokenVaults;
        mapping (uint256 => IWittyPixelsTokenVault) vaults;

        // --- WittyPixelsToken
        uint mintingTokenId;
        mapping (uint256 => ERC721TokenWitnetRequests) witnetRequests;
        mapping (uint256 => uint256) tokenVaultIndex;
        mapping (uint256 => ERC721TokenSponsors) sponsors;        
    }

    struct TokenVaultOwnershipDeeds {
        address parentToken;
        uint256 parentTokenId;
        address playerAddress;
        uint256 playerIndex;
        uint256 playerPixels;
        bytes32[] playerPixelsProof;
        bytes signature;
    }

    struct TokenVaultInitParams {
        address curator;
        string  name;
        bytes   settings;
        string  symbol;
        address token;
        uint256 tokenId;
        uint256 tokenPixels;
    }

    struct TokenVaultStorage {
        // --- IERC1633
        address parentToken;
        uint256 parentTokenId;

        // --- IWittyPixelsTokenVault
        address curator;
        uint256 finalPrice;
        bytes32 witnetRandomness;
        uint256 witnetRandomnessBlock;
        
        IWittyPixelsTokenVaultAuctionDutch.Settings settings;
        IWittyPixelsTokenVault.Stats stats;
        
        address[] authors;
        mapping (address => uint256) legacyPixels;
        mapping (uint256 => TokenVaultPlayerInfo) players;        
        mapping (address => TokenVaultJackpotWinner) winners;
    }

    struct TokenVaultJackpotWinner {
        bool awarded;
        bool claimed;
        uint256 index;
    }

    struct TokenVaultPlayerInfo {
        address addr;
        uint256 pixels;
    }

    enum ERC721TokenStatus {
        Void,
        Launching,
        Minting,
        Fractionalized,
        Acquired
    }

    struct ERC721Token {
        string  baseURI;
        uint256 birthTs;        
        bytes32 imageWitnetTxHash;         
        bytes32 statsWitnetTxHash;
        ERC721TokenEvent theEvent;
        ERC721TokenStats theStats;
    }
    
    struct ERC721TokenEvent {
        string  name;
        string  venue;
        uint256 startTs;
        uint256 endTs;
    }

    struct ERC721TokenStats {
        bytes32 authorshipsRoot;
        string  canvasDigest;
        uint256 canvasHeight;
        uint256 canvasPixels;
        uint256 canvasWidth;
        uint256 totalPixels;
        uint256 totalPlayers;
        uint256 totalScans;
    }

    struct ERC721TokenSponsors {
        address[] addresses;
        uint256 totalJackpots;        
        mapping (address => ERC721TokenJackpot) jackpots;
    }

    struct ERC721TokenJackpot {
        bool authorized;
        address winner;
        uint256 value;
        string text;
    }
    
    struct ERC721TokenWitnetRequests {
        WitnetRequestTemplate imageDigest;
        WitnetRequestTemplate tokenStats;
    }

    function toJSON(
            ERC721Token memory self,
            uint256 tokenId,
            bytes32 tokenStatsRadHash
        )
        public pure
        returns (string memory)
    {
        string memory _tokenIdString = toString(tokenId);
        string memory _name = string(abi.encodePacked(
            "\"name\": \"WittyPixels.art #", _tokenIdString, "\","
        ));
        string memory _description = string(abi.encodePacked(
            "\"description\": \"",
            _loadJsonDescription(self, tokenStatsRadHash),
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

    function _loadJsonAttributes(ERC721Token memory self)
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
                "\"value\": \"", toHexString(self.theStats.authorshipsRoot), "\"",
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

    function _loadJsonCanvasAttributes(ERC721Token memory self)
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
                "\"value\": \"", self.theStats.canvasDigest, "\"",
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

    function _loadJsonDescription(ERC721Token memory self, bytes32 tokenStatsRadHash)
        private pure
        returns (string memory)
    {
        string memory _totalPlayersString = toString(self.theStats.totalPlayers);
        string memory _radHashHexString = toHexString(tokenStatsRadHash);
        return string(abi.encodePacked(
            "WittyPixelsTM collaborative art canvas drawn by ", _totalPlayersString,
            " attendees during '", self.theEvent.name, "' in ", self.theEvent.venue, 
            ". This token was fractionalized and secured by the [Witnet multichain",
            " oracle](https://witnet.io). Historical WittyPixelsTM game info and",
            " authorship's root during '", self.theEvent.name, "'",
            " can be audited on [Witnet's block explorer](https://witnet.network/",
            _radHashHexString, ")."
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
                ] == bytes1("/")
            ), "WittyPixelsLib: bad uri"
        );
        return uri;
    }

    function tokenImageURI(uint256 tokenId, string memory baseURI) internal pure returns (string memory) {
        return string(abi.encodePacked(
            baseURI,
            "image/",
            toString(tokenId)
        ));
    }

    function tokenMetadataURI(uint256 tokenId, string memory baseURI) internal pure returns (string memory) {
        return string(abi.encodePacked(
            baseURI,
            "metadata/",
            toString(tokenId)
        ));
    }

    function tokenStatsURI(uint256 tokenId, string memory baseURI) internal pure returns (string memory) {
        return string(abi.encodePacked(
            baseURI,
            "stats/",
            toString(tokenId)
        ));
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
            root = _hash(root, proof[i]);
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

    /// @dev Converts a `uint256` to its ASCII `string` decimal representation.
    function toString(uint256 value) internal pure returns (string memory) {
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
    function toHexString(bytes32 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(64);
        for (uint256 i = 64; i > 0; i --) {
            buffer[i - 1] = _HEX_SYMBOLS_[uint(value) & 0xf];
            value >>= 4;
        }
        return string(buffer);
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