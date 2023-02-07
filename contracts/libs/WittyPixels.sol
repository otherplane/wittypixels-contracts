// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "witnet-solidity-bridge/contracts/requests/WitnetRequestTemplate.sol";
import "../interfaces/IWittyPixelsTokenVault.sol";

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
        uint256 totalPixels;
    }

    enum TokenVaultStatus {
        Awaiting,
        Randomizing,
        Auctioning,
        Sold
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
        SoldOut
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
        bytes32 playersRoot;
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

    function checkBaseURI(string memory uri)
        internal pure
        returns (string memory)
    {
        require((
            bytes(uri).length > 0
                && bytes(uri)[
                    bytes(uri).length - 1
                ] == bytes1("/")
            ), "WittyPixels: bad uri"
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
            revert("WittyPixels: invalid hex");
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