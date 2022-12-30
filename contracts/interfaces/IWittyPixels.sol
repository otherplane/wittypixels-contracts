// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libs/WittyPixels.sol";

interface IWittyPixels {
    function baseURI() external view returns (string memory);
    function getTokenMetadata(uint256 tokenId) external view returns (WittyPixels.TokenMetadata memory);
    function getTokenStatus(uint256 tokenId) external view returns (WittyPixels.TokenStatus);
    function getTokenVault(uint256 tokenId) external view returns (ITokenVaultWitnet);    
    function getTokenWitnetRequests(uint256 tokenId) external view returns (WittyPixels.TokenWitnetRequests memory);
    function metadata(uint256 tokenId) external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function verifyTokenPlayerScore(uint256 tokenId, uint256 index, uint256 score, bytes32[] calldata proof) external view returns (bool);
    function verifyTokenPlayerName(uint256 tokenId, uint256 index, string calldata name, bytes32[] calldata proof) external view returns (bool);
}