// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IWittyPixelsTokenVaultJackpots {

    event Winner(address winner, uint index);

    function claimJackpot() external returns (uint256);

    function getJackpotByIndex(uint256 index) external view returns (
            address sponsor,
            address winner,
            uint256 value,
            string memory text
        );
    function getJackpotByWinner(address winner) external view returns (
            uint256 index,
            address sponsor,
            uint256 value,
            string memory text
        );
    function getJackpotsContestantsCount() external view returns (uint256);
    function getJackpotsContestantsAddresses(uint offset, uint size) external view returns (address[] memory);
    function getJackpotsCount() external view returns (uint256);    
    function getJackpotsTotalValue() external view returns (uint256);
        
    function randomizeWinners() external payable;
    function settleWinners() external;

}    
