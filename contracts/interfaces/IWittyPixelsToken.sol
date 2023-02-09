// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libs/WittyPixelsLib.sol";

interface IWittyPixelsToken {

    function baseURI() external view returns (string memory);
    function getTokenMetadata(uint256 tokenId) external view returns (WittyPixelsLib.ERC721Token memory);
    function getTokenStatus(uint256 tokenId) external view returns (WittyPixelsLib.ERC721TokenStatus);
    function getTokenStatusString(uint256 tokenId) external view returns (string memory);
    function getTokenVault(uint256 tokenId) external view returns (ITokenVaultWitnet);    
    function getTokenWitnetRequests(uint256 tokenId) external view returns (WittyPixelsLib.ERC721TokenWitnetRequests memory);
    function verifyTokenAuthorship(
            uint256 tokenId,
            uint256 playerIndex,
            uint256 playerPixels,
            bytes32[] calldata authorshipProof
        ) external view returns (bool);
}