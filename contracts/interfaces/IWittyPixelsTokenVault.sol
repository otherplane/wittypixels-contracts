// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ITokenVaultWitnet.sol";
import "./IWittyPixelsTokenVaultAuctionDutch.sol";
import "./IWittyPixelsTokenVaultJackpots.sol";

abstract contract IWittyPixelsTokenVault
    is
        ITokenVaultWitnet,
        IWittyPixelsTokenVaultAuctionDutch,
        IWittyPixelsTokenVaultJackpots
{
    constructor(address _randomizer)
        ITokenVaultWitnet(_randomizer)
    {}

    struct Stats {
        uint256 redeemedPixels;
        uint256 redeemedPlayers;
        uint256 totalPixels;
        uint256 totalTransfers;
        uint256 totalWithdrawals;
    }

    enum Status {
        /* 0 */ Awaiting,
        /* 1 */ Randomizing,
        /* 2 */ Auctioning,
        /* 3 */ Sold
    }

    /// @notice Returns number of legitimate players that have redeemed authorhsip of at least one pixel from the NFT token.
    function getAuthorsCount() virtual external view returns (uint256);

    /// @notice Returns range of authors, as specified by `offset` and `count` params.
    function getAuthorsRange(uint offset, uint count) virtual external view returns (address[] memory);

    /// @notice Returns status data about the token vault contract, relevant from an UI/UX perspective
    /// @return status Enum value representing current contract status: Awaiting, Randomizing, Auctioning, Sold
    /// @return stats Set of meters reflecting number of pixels, players, ERC20 transfers and withdrawls, up to date. 
    /// @return currentPrice Price in ETH/wei at which the whole NFT ownership can be bought, or at which it was actually sold.
    /// @return nextPriceBlock A block number in the future at which the currentPrice may change. Zero, if it's not expected ever to change.    
    function getInfo() virtual external view returns (
            Status  status,
            Stats memory stats,
            uint256 currentPrice,
            uint256 nextPriceBlock
        );

    /// @notice Gets info regarding a formerly verified player, given its index. 
    /// @return playerAddress Address from which the token's ownership was redeemed. Zero if this player has redeemed ownership yet.
    /// @return redeemedPixels Number of pixels formerly redemeed by given player. 
    function getPlayerInfo(uint256) virtual external view returns (
            address playerAddress,
            uint256 redeemedPixels
        );

    /// @notice Gets accounting info regarding given address.
    /// @return sharePercentage100 NFT ownership percentage based on current ERC20 balance, multiplied by a 100.
    /// @return withdrawableFunds ETH/wei amount that can be potentially withdrawn from this address.
    function getWalletInfo(address) virtual external view returns (
            uint16  sharePercentage100,
            uint256 withdrawableFunds
        );

    /// @notice Returns sum of legacy pixels ever redeemed from the given address.
    /// The moral right over a player's finalized pixels is inalienable, so the value returned by this method
    /// will be preserved even though the player transfers ERC20/WPX tokens to other accounts, or if she decides to cash out 
    /// her share if the parent NFT token ever gets sold out. 
    function pixelsOf(address) virtual external view returns (uint256);

    /// @notice Returns total number of finalized pixels within the WittyPixels canvas.
    function totalPixels() virtual external view returns (uint256);   
}