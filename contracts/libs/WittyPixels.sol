// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "witnet-solidity-bridge/contracts/requests/WitnetRequestTemplate.sol";
import "../interfaces/ITokenVaultWitnet.sol";

library WittyPixels {

    enum TokenStatus {
        Void,
        Minting,
        Minted,
        Fractionalized,
        SoldOut
    }

    struct TokenEvent {
        string  name;
        string  venue;
        uint256 startTs;
        uint256 endTs;
    }

    struct TokenCanvas {
        uint256 colors;
        uint256 height;
        uint256 width;
    }

    struct TokenRoots {
        bytes32 data;
        bytes32 names;
        bytes32 scores;
    }

    struct TokenStats {
        uint256 totalPixels;
        uint256 totalPlayers;
        uint256 totalPlays;
        uint256 totalScore;
    }
    
    struct TokenMetadata {
        uint256 block;
        string  imageURI;
        bytes32 imageDigest;
        TokenEvent theEvent;
        TokenCanvas theCanvas;
        TokenStats theStats;
        TokenRoots theRoots;
    }

    struct TokenWitnetRequests {
        WitnetRequestTemplate imageDigest;
        WitnetRequestTemplate tokenRoots;
    }

    struct TokenStorage {
        // --- Upgradable
        address base;
        
        // --- Ownable
        address owner;
        
        // --- Ownable2Step
        address pendingOwner;
        
        // --- ERC721
        string  baseURI;
        uint256 totalSupply;
        mapping (uint256 => TokenMetadata) items;
        
        // --- ITokenVaultFactory
        ITokenVaultWitnet tokenVaultPrototype;
        uint256 totalTokenVaults;
        mapping (uint256 => ITokenVaultWitnet) vaults;

        // --- WittyPixelsToken
        uint mintingTokenId;
        mapping (uint256 => TokenWitnetRequests) witnetRequests;
        mapping (uint256 => uint256) tokenVaultIndex;
    }

    struct TokenVaultInitParams {
        address curator;
        uint256 tokenId;
        uint256 erc20Supply;
        string  erc20Name;
        string  erc20Symbol;
        bytes   settings;
    }

    struct TokenVaultSettings {
        uint256 listPriceWei;
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

    function checkImageURI(string memory uri)
        internal pure
        returns (string memory)
    {
        // TODO
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

    function toJSON(TokenMetadata memory self)
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