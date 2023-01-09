// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "witnet-solidity-bridge/contracts/requests/WitnetRequestTemplate.sol";
import "../interfaces/IWittyPixelsTokenVault.sol";

library WittyPixels {

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
        uint256 playerScore;
        bytes32[] playerScoreProof;
    }

    struct TokenVaultInitParams {
        address curator;
        string  name;
        bytes   settings;
        uint256 supply;
        string  symbol;
        uint256 tokenId;      
    }

    struct TokenVaultStorage {
        // --- IERC1633
        address parentToken;
        uint256 parentTokenId;

        // --- IWittyPixelsTokenVault
        address curator;
        uint256 finalPrice;
        uint256 totalScore;
        uint256 totalSupply;
        bytes32 witnetRandomness;
        uint256 witnetRandomnessBlock;
        address[] members;
        mapping (uint256 => bool) mints;
        mapping (address => uint256) withdrawals;
        mapping (address => TokenVaultJackpotWinner) winners;        
        IWittyPixelsTokenVaultAuctionDutch.Settings settings;
    }

    struct TokenVaultJackpotWinner {
        bool awarded;
        bool claimed;
        uint256 index;
    }

    enum ERC721TokenStatus {
        Void,
        Launching,
        Minting,
        Fractionalized,
        SoldOut
    }

    struct ERC721Token {
        string  imageURI;
        ERC721TokenEvent theEvent;
        ERC721TokenStats theStats;
        ERC721TokenRoots theRoots;
    }
    
    struct ERC721TokenEvent {
        string  name;
        string  venue;
        uint256 startTs;
        uint256 endTs;
    }

    struct ERC721TokenRoots {
        bytes32 image;
        bytes32 scores;
        bytes32 stats;
    }

    struct ERC721TokenStats {
        uint256 totalPixels;
        uint256 totalPlayers;
        uint256 totalPlays;
        uint256 totalScore;
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
        WitnetRequestTemplate tokenRoots;
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

    function toJSON(ERC721Token memory self)
        internal pure
        returns (string memory)
    {
        // TODO
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