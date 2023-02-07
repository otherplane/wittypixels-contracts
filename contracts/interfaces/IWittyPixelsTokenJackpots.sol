// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libs/WittyPixelsLib.sol";

interface IWittyPixelsTokenJackpots {
    event Jackpot(uint256 tokenId, uint256 index, address winner, uint256 jackpot);
    function getTokenJackpotByIndex(uint256 tokenId, uint256 index)
        external view
        returns (
            address sponsor,
            address winner,
            uint256 value,
            string memory text
        );
    function getTokenJackpotsCount(uint256 tokenId) external view returns (uint256);
    function getTokenJackpotsTotalValue(uint256 tokenId) external view returns (uint256);
    function sponsoriseToken(uint256 tokenId) external payable;
    function transferTokenJackpot(uint256 tokenId, uint256 index, address payable winner) external returns (uint256);
}