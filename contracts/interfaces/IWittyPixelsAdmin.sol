// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC165.sol";
import "../libs/WittyPixels.sol";

interface IWittyPixelsAdmin {

    error PremintPendingResponse (uint tokenId, string uri);
    error PremintFailedResponse  (uint tokenId, string uri, string reason);
    error PremintValidationFailed(uint tokenId, string uri, string reason);
    
    event Minting(uint256 tokenId, string baseURI, string imageURI, bytes32 slaHash);

    function premint(
            uint256 tokenId,
            string calldata imageURI,
            bytes32 tallyHash,
            bytes32 slaHash
        ) external payable;

    /// @notice Mint new WittyPixels token: one new token id per TokenEvent where WittyPixelsTM is played.
    function mint(
            uint256 tokenId,
            WittyPixels.TokenEvent memory theEvent,
            WittyPixels.TokenCanvas memory theCanvas,
            WittyPixels.TokenStats memory theStats
        ) external;

    /// @notice Sets collection's base URI.
    function setBaseURI(string calldata baseURI) external;

    /// @notice Sets token vault contract to be used as prototype.
    /// @dev Prototype ownership needs to have been previously transferred to this contract.
    function setTokenVaultPrototype(address prototype) external;    

    // /// @notice Upgrade previously owned vault logic contract.
    // function upgradeBasement(
    //         IERC165 oldVaultLogic,
    //         IERC165 newVaultLogic,
    //         bytes calldata initArgs
    //     ) external;
}