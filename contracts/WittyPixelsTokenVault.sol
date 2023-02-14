// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./interfaces/IWittyPixelsToken.sol";
import "./interfaces/IWittyPixelsTokenVault.sol";
import "./interfaces/IWittyPixelsTokenJackpots.sol";

import "./patterns/WittyPixelsClonableBase.sol";

contract WittyPixelsTokenVault
    is
        ERC20Upgradeable,
        IWittyPixelsTokenVault,
        WittyPixelsClonableBase
{
    using ERC165Checker for address;

    WittyPixelsLib.TokenVaultStorage internal __storage;

    modifier notAcquiredYet {
        require(
            !acquired(),
            "WittyPixelsTokenVault: already acquired"
        );
        _;
    }

    modifier onlyCurator {
        require(
            msg.sender == __storage.curator,
            "WittyPixelsTokenVault: not the curator"
        );
        _;
    }

    modifier wasRandomized {
        require(
            randomized(),
            "WittyPixelsTokenVault: not yet randomized"
        );
        _;
    }

    constructor (
            address _randomizer,
            bytes32 _version
        )
        IWittyPixelsTokenVault(_randomizer)
        WittyPixelsClonableBase(_version)
    {}

    receive() external payable {}


    // ================================================================================================================
    // --- Overrides IERC20Upgradeable interface ----------------------------------------------------------------------

    /// @notice Increment `__storage.stats.totalTransfers` every time an ERC20 transfer is confirmed.
    /// @dev Hook that is called after any transfer of tokens. This includes minting and burning.
    /// Calling conditions:
    /// - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens has been transferred to `to`.
    /// - when `from` is zero, `amount` tokens have been minted for `to`.
    /// - when `to` is zero, `amount` of ``from``'s tokens have been burned.
    /// - `from` and `to` are never both zero.
    function _afterTokenTransfer(
            address _from,
            address _to,
            uint256
        )
        internal
        virtual override
    {
        if (
            _from != address(0)
                && _to != address(0)
        ) {
            __storage.stats.totalTransfers ++;
        }
    }


    // ================================================================================================================
    // --- Overrides IERC165 interface --------------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId)
      public view
      virtual override
      returns (bool)
    {
        return _interfaceId == type(IERC165).interfaceId
            || _interfaceId == type(IWittyPixelsTokenVault).interfaceId
            || _interfaceId == type(ITokenVault).interfaceId
            || _interfaceId == type(IERC1633).interfaceId
            || _interfaceId == type(IERC20Upgradeable).interfaceId
            || _interfaceId == type(IERC20MetadataUpgradeable).interfaceId
            || _interfaceId == type(Clonable).interfaceId
        ;
    }


    // ================================================================================================================
    // --- Implements 'IERC1633' --------------------------------------------------------------------------------------

    function parentToken()
        override
        external view
        returns (address)
    {
        return __storage.parentToken;
    }

    function parentTokenId()
        override
        external view
        returns(uint256)
    {
        return __storage.parentTokenId;
    }


    // ================================================================================================================
    // --- Implements 'ITokenVault' -----------------------------------------------------------------------------------

    /// @notice Address of the previous owner, the one that decided to fractionalized the NFT.
    function curator()
        override
        external view
        wasInitialized
        returns (address)
    {
        return __storage.curator;
    }

    /// @notice Mint ERC-20 tokens, ergo token ownership, by providing ownership deeds.
    function redeem(bytes calldata _deedsdata)
        virtual override
        public
        wasInitialized
        nonReentrant
    {
        // deserialize deeds data:
        WittyPixelsLib.TokenVaultOwnershipDeeds memory _deeds = abi.decode(
            _deedsdata,
            (WittyPixelsLib.TokenVaultOwnershipDeeds)
        );
        
        // verify curator's signature:
        bytes32 _deedshash = keccak256(abi.encode(
            _deeds.parentToken,
            _deeds.parentTokenId,
            _deeds.playerAddress,
            _deeds.playerIndex,
            _deeds.playerPixels,
            _deeds.playerPixelsProof
        ));
        require(
            WittyPixelsLib.recoverAddr(_deedshash, _deeds.signature) == __storage.curator,
            "WittyPixelsTokenVault: bad signature"
        );
        
        // verify intrinsicals:
        require(
            _deeds.parentToken == __storage.parentToken
                && _deeds.parentTokenId == __storage.parentTokenId
            , "WittyPixelsTokenVault: bad token"
        );
        require(
            _deeds.playerAddress != address(0),
            "WittyPixelsTokenVault: null address"
        );
        require(
            __storage.players[_deeds.playerIndex].addr == address(0),
            "WittyPixelsTokenVault: already redeemed"
        );
        require(
            __storage.stats.redeemedPixels + _deeds.playerPixels <= __storage.stats.totalPixels,
            "WittyPixelsTokenVault: overbooking :/"
        );
        
        // verify player's score proof:
        require(
            IWittyPixelsToken(_deeds.parentToken).verifyTokenAuthorship(
                _deeds.parentTokenId,
                _deeds.playerIndex,
                _deeds.playerPixels,
                _deeds.playerPixelsProof
            ),
            "WittyPixelsTokenVault: false deeds"
        );
        
        // store player's info:
        uint _currentPixels = __storage.legacyPixels[_deeds.playerAddress];
        if (
            _currentPixels == 0
                && !__storage.redeemed[_deeds.playerAddress]
        ) {
            // upon first redemption from playerAddress, add it to the author's list
            __storage.authors.push(_deeds.playerAddress);
            __storage.redeemed[_deeds.playerAddress] = true;
        }
        if (_deeds.playerPixels > 0) {
            __storage.legacyPixels[_deeds.playerAddress] = _currentPixels + _deeds.playerPixels;    
        }
        __storage.players[_deeds.playerIndex] = WittyPixelsLib.TokenVaultPlayerInfo({
            addr: _deeds.playerAddress,
            pixels: _deeds.playerPixels
        });

        // update stats meters:
        __storage.stats.redeemedPixels += _deeds.playerPixels;
        __storage.stats.redeemedPlayers ++;

        // transfer sovereign tokens to player's verified address:
        _transfer(
            address(this),
            _deeds.playerAddress,
            _deeds.playerPixels * 10 ** 18
        );
    }

    /// @notice Returns whether this NFT vault has already been acquired. 
    function acquired()
        override
        public view
        wasInitialized
        returns (bool)
    {
        return IERC721(__storage.parentToken).ownerOf(__storage.parentTokenId) != address(this);
    }

    /// @notice Withdraw paid value in proportion to number of shares.
    /// @dev Fails if not yet acquired. 
    function withdraw()
        virtual override
        public
        wasInitialized
        nonReentrant
        returns (uint256 _withdrawn)
    {
        // check the nft token has indeed been acquired:
        require(
            acquired(),
            "WittyPixelsTokenVault: not acquired yet"
        );
        
        // check caller's erc20 balance is greater than zero:
        uint _erc20balance = balanceOf(msg.sender);
        require(
            _erc20balance > 0,
            "WittyPixelsTokenVault: no balance"
        );
        
        // check vault contract has enough funds for the cash out:
        _withdrawn = (__storage.finalPrice * _erc20balance) / (__storage.stats.totalPixels * 10 ** 18);
        require(
            address(this).balance >= _withdrawn,
            "WittyPixelsTokenVault: insufficient funds"
        );
        
        // burn erc20 tokens about to be cashed out:
        _burn(msg.sender, _erc20balance);
        
        // cash out: 
        payable(msg.sender).transfer(_withdrawn);
        emit Withdrawal(msg.sender, _withdrawn);

        // update stats meters:
        __storage.stats.totalWithdrawals ++;
    }

    /// @notice Tells withdrawable amount in weis from the given address.
    /// @dev Returns 0 in all cases while not yet acquired. 
    function withdrawableFrom(address _from)
        virtual override
        public view
        wasInitialized
        returns (uint256)
    {
        if (acquired()) {
            return (__storage.finalPrice * balanceOf(_from)) / (__storage.stats.totalPixels * 10 ** 18);
        } else {
            return 0;
        }
    }


    // ================================================================================================================
    // --- Implements ITokenVaultWitnet -------------------------------------------------------------------------------

    function cloneAndInitialize(bytes memory _initdata)
        virtual override
        external
        returns (ITokenVaultWitnet)
    {
        return _afterCloning(_clone(), _initdata);
    }

    function cloneDeterministicAndInitialize(bytes32 _salt, bytes memory _initdata)
        virtual override
        external
        returns (ITokenVaultWitnet)
    {
        return _afterCloning(_cloneDeterministic(_salt), _initdata);
    }

    function getRandomizeBlock()
        override
        external view
        returns (uint256)
    {
        return __storage.witnetRandomnessBlock;
    }

    function randomized()
        override
        public view
        returns (bool)
    {
        return (
            __storage.witnetRandomnessBlock != 0
                && randomizer.isRandomized(__storage.witnetRandomnessBlock)
        );
    }

    function randomizing()
        override
        public view
        returns (bool)
    {
        return (
            __storage.witnetRandomnessBlock != 0 
                && !randomizer.isRandomized(__storage.witnetRandomnessBlock)
        );
    }


    // ================================================================================================================
    // --- Implements 'IWittyPixelsTokenVault' ------------------------------------------------------------------------
    
    /// @notice Returns number of legitimate players that have redeemed authorhsip of at least one pixel from the NFT token.
    function getAuthorsCount()
        virtual override
        external view
        wasInitialized
        returns (uint256)
    {
        return __storage.authors.length;
    }

    /// @notice Returns range of authors, as specified by `offset` and `count` params.
    function getAuthorsRange(uint offset, uint count)
        virtual override
        external view
        wasInitialized
        returns (address[] memory _authors)
    {
        uint _total = __storage.authors.length;
        if (offset < _total) {
            if (offset + count > _total) {
                count = _total - offset;
            }
            _authors = new address[](count);
            for (uint _i = 0; _i < count; _i ++) {
                _authors[_i] = __storage.authors[_i + offset];
            }
        }
    }

    /// @notice Returns status data about the token vault contract, relevant from an UI/UX perspective
    /// @return status Enum value representing current contract status: Awaiting, Randomizing, Auctioning, Sold
    /// @return stats Set of meters reflecting number of pixels, players, ERC20 transfers and withdrawls, up to date. 
    /// @return currentPrice Price in ETH/wei at which the whole NFT ownership can be bought, or at which it was actually sold.
    /// @return nextPriceTs The approximate timestamp at which the currentPrice may change. Zero, if it's not expected to ever change again.
    function getInfo()
        override
        external view
        wasInitialized
        returns (
            Status status,
            Stats memory stats,
            uint256 currentPrice,
            uint256 nextPriceTs
        )
    {
        if (acquired()) {
            status = IWittyPixelsTokenVault.Status.Acquired;
        } else if (randomizing()) {
            status = IWittyPixelsTokenVault.Status.Randomizing;
        } else if (auctioning()) {
            status = IWittyPixelsTokenVault.Status.Auctioning;
        } else {
            status = IWittyPixelsTokenVault.Status.Awaiting;
        }
        stats = __storage.stats;
        currentPrice = getPrice();
        nextPriceTs = getNextPriceTimestamp();
    }

    /// @notice Gets info regarding a formerly verified player, given its index. 
    /// @return Address from which the token's ownership was redeemed. Zero if this player hasn't redeemed ownership yet.
    /// @return Number of pixels formerly redemeed by given player. 
    function getPlayerInfo(uint256 index)
        virtual override
        external view
        wasInitialized
        returns (address, uint256)
    {
        WittyPixelsLib.TokenVaultPlayerInfo storage __info = __storage.players[index];
        return (
            __info.addr,
            __info.pixels
        );
    }

    /// @notice Gets accounting info regarding given address.
    /// @return sharePer10000 NFT ownership percentage based on current ERC20 balance, multiplied by a 100.
    /// @return withdrawableFunds ETH/wei amount that can be potentially withdrawn from this address.
    /// @return legacyPixels Soulbound pixels contributed from this wallet address, if any.
    function getWalletInfo(address _addr)
        virtual override
        external view
        wasInitialized
        returns (
            uint256 sharePer10000,
            uint256 withdrawableFunds,
            uint256 legacyPixels
        )
    {
        return (
            (10 ** 4 * balanceOf(_addr)) / (__storage.stats.totalPixels * 10 ** 18),
            withdrawableFrom(_addr),
            pixelsOf(_addr)
        );
    }

    /// @notice Returns sum of legacy pixels ever redeemed from the given address.
    /// The moral right over a player's finalized pixels is inalienable, so the value returned by this method
    /// will be preserved even though the player transfers ERC20/WPX tokens to other accounts, or if she decides to cash out 
    /// her share if the parent NFT token ever gets acquired. 
    function pixelsOf(address _wallet)
        virtual override
        public view
        wasInitialized
        returns (uint256)
    {
        return __storage.legacyPixels[_wallet];
    }    

    /// @notice Returns total number of finalized pixels within the WittyPixelsLib canvas.
    function totalPixels()
        virtual override
        external view
        wasInitialized
        returns (uint256)
    {
        return __storage.stats.totalPixels;
    }

    
    // ================================================================================================================
    // --- Implements 'IWittyPixelsTokenVaultAuctionDutch' ------------------------------------------------------------

    function acquire()
        override
        external payable
        wasInitialized
        nonReentrant
        notAcquiredYet
    {
        // verify provided value is greater or equal to current price:
        uint256 _finalPrice = getPrice();
        require(
            msg.value >= _finalPrice,
            "WittyPixelsTokenVault: insufficient value"
        );

        // safely transfer parent token id ownership to the bidder:
        IERC721(__storage.parentToken).safeTransferFrom(
            address(this),
            msg.sender,
            __storage.parentTokenId
        );

        // store final price:
        __storage.finalPrice = _finalPrice;
        
        // transfer back unused funds if `msg.value` was higher than current price:
        if (msg.value > _finalPrice) {
            payable(msg.sender).transfer(msg.value - _finalPrice);
        }
    }

    function auctioning()
        virtual override
        public view
        wasInitialized
        returns (bool)
    {
        uint _startingTs = __storage.settings.startingTs;
        return (
            _startingTs != 0
                && block.timestamp >= _startingTs
                && !acquired()
        );
    }

    function getAuctionSettings()
        override
        external view
        wasInitialized
        returns (bytes memory)
    {
        return abi.encode(__storage.settings);
    }

    function getAuctionType()
        override
        external pure
        returns (bytes4)
    {
        return type(IWittyPixelsTokenVaultAuctionDutch).interfaceId;
    }

    function setAuctionSettings(bytes memory _settings)
        override
        external
        onlyCurator
        notAcquiredYet
    {
        _setAuctionSettings(_settings);
    }

    function getPrice()
        virtual override
        public view
        wasInitialized
        returns (uint256)
    {
        IWittyPixelsTokenVaultAuctionDutch.Settings memory _settings = __storage.settings;
        if (block.timestamp >= _settings.startingTs) {
            if (__storage.finalPrice == 0) {
                uint _tsDiff = block.timestamp - _settings.startingTs;
                uint _priceRange = _settings.startingPrice - _settings.reservePrice;
                uint _round = _tsDiff / _settings.deltaSeconds;
                if (_round * _settings.deltaPrice <= _priceRange) {
                    return _settings.startingPrice - _round * _settings.deltaPrice;
                } else {
                    return _settings.reservePrice;
                }
            } else {
                return __storage.finalPrice;
            }
        } else {
            return _settings.startingPrice;
        }
    }


    // ================================================================================================================
    // --- Implements 'IWittyPixelsTokenVaultAuctionDutch' ------------------------------------------------------------

    function getNextPriceTimestamp()
        override
        public view
        wasInitialized
        returns (uint256)
    {
        IWittyPixelsTokenVaultAuctionDutch.Settings memory _settings = __storage.settings;
        if (
            acquired()
                || getPrice() == _settings.reservePrice
        ) {
            return 0;
        }
        else if (block.timestamp >= _settings.startingTs) {
            uint _tsDiff = block.timestamp - _settings.startingTs;
            uint _round = _tsDiff / _settings.deltaSeconds;
            return (
                _settings.startingTs
                    + _settings.deltaSeconds * (_round + 1)
            );
        }
        else {
            return _settings.startingTs;
        }
    }    


    // ================================================================================================================
    // --- Implements 'IWittyPixelsTokenVaultJackpots' ---------------------------------------------------------------------

    function claimJackpot()
        override
        external
        wasRandomized
        nonReentrant
        returns (uint256)
    {
        WittyPixelsLib.TokenVaultJackpotWinner storage __winner = __storage.winners[msg.sender];
        require(
            __winner.awarded,
            "WittyPixelsTokenVault: not awarded"
        );
        require(
            !__winner.claimed,
            "WittyPixelsTokenVault: already claimed"
        );
        __winner.claimed = true;        
        return IWittyPixelsTokenJackpots(__storage.parentToken).transferTokenJackpot(
            __storage.parentTokenId,
            __winner.index,
            payable(msg.sender)
        );
    }

    function getJackpotByIndex(uint256 _index)
        override
        external view
        wasInitialized
        returns (address, address, uint256, string memory)
    {
        return IWittyPixelsTokenJackpots(__storage.parentToken).getTokenJackpotByIndex(
            __storage.parentTokenId,
            _index
        );
    }

    function getJackpotByWinner(address _winner)
        override
        external view
        wasInitialized
        returns (
            uint256 _index,
            address _sponsor,
            uint256 _value,
            string memory _text
        )
    {
        WittyPixelsLib.TokenVaultJackpotWinner storage __winner = __storage.winners[_winner];
        require(
            __winner.awarded,
            "WittyPixelsTokenVault: not a winner"
        );
        _index = __winner.index;
        (_sponsor,, _value, _text) = IWittyPixelsTokenJackpots(__storage.parentToken).getTokenJackpotByIndex(
            __storage.parentTokenId,
            _index
        );
    }

    function getJackpotsContestantsCount()
        override
        external view
        returns (uint256)
    {
        return __storage.authors.length;
    }

    function getJackpotsContestantsAddresses(uint _offset, uint _size)
        override
        external view
        returns (address[] memory _addrs)
    {
        require(
            _offset + _size <= __storage.authors.length,
            "WittyPixelsTokenVault: out of range"
        );
        _addrs = new address[](_size);
        address[] storage __members = __storage.authors;
        for (uint _i = 0; _i < _size; _i ++) {
            _addrs[_i] = __members[_offset + _i];
        }
    }

    function getJackpotsCount()
        override
        public view
        wasInitialized
        returns (uint256)
    {
        return IWittyPixelsTokenJackpots(__storage.parentToken).getTokenJackpotsCount(
            __storage.parentTokenId
        );
    }
    
    function getJackpotsTotalValue()
        override
        external view
        wasInitialized
        returns (uint256)
    {
        return IWittyPixelsTokenJackpots(__storage.parentToken).getTokenJackpotsTotalValue(
            __storage.parentTokenId
        );
    }

    function randomizeWinners()
        override 
        external payable
        wasInitialized
        nonReentrant
        onlyCurator
    {
        require(
            block.timestamp >= __storage.settings.startingTs,
            "WittyPixelsTokenVault: not yet possible"
        );
        require(
            __storage.witnetRandomness != 0,
            "WittyPixelsTokenVault: already randomized"
        );
        require(
            __storage.witnetRandomnessBlock == 0,
            "WittyPixelsTokenVault: already randomizing"
        );
        require(
            getJackpotsCount() > 0,
            "WittyPixelsTokenVault: no jackpots"
        );
        require(
            __storage.authors.length >= getJackpotsCount(),
            "WittyPixelsTokenVault: not enough contestants"
        );
        __storage.witnetRandomnessBlock = block.number;
        uint _usedFunds = randomizer.randomize{value: msg.value}();
        if (_usedFunds < msg.value) {
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }
    }

    function settleWinners()
        override
        external
    {
        require(
            randomizing(),
            "WittyPixelsTokenVault: not randomizing"
        );
        bytes32 _randomness = randomizer.getRandomnessAfter(__storage.witnetRandomnessBlock);
        address[] storage __members = __storage.authors;        
        uint _jackpots = getJackpotsCount();        
        uint32 _contestants = uint32(__members.length);
        for (uint _jackpotIndex = 0; _jackpotIndex < _jackpots; _jackpotIndex ++) {
            uint _winnerIndex = randomizer.random(
                _contestants,
                _jackpotIndex,
                _randomness
            );
            address _winnerAddr = __members[_winnerIndex];
            if (_winnerIndex != _contestants - 1) {
                __members[_winnerIndex] = __members[_contestants - 1];
                __members[_contestants - 1] = _winnerAddr;
            }
            __storage.winners[_winnerAddr] = WittyPixelsLib.TokenVaultJackpotWinner({
                awarded: true,
                claimed: false,
                index  : _jackpotIndex
            });
            emit Winner(_winnerAddr, _jackpotIndex);
            _contestants --;
        }
        __storage.witnetRandomness = _randomness;
    }


    // ================================================================================================================
    // --- Overrides 'Clonable' ---------------------------------------------------------------------------------------

    function initialized()
        override
        public view
        returns (bool)
    {
        return __storage.curator != address(0);
    }

    /// Initialize storage-context when invoked as delegatecall. 
    /// @dev Must fail when trying to initialize same instance more than once.
    function _initialize(bytes memory _initBytes) 
        virtual override
        internal
    {   
        super._initialize(_initBytes);

        // decode and validate initialization parameters:
        WittyPixelsLib.TokenVaultInitParams memory _params = abi.decode(
            _initBytes,
            (WittyPixelsLib.TokenVaultInitParams)
        );
        require(
            _params.curator != address(0),
            "WittyPixelsTokenVault: no curator"
        );
        require(
            _params.token.supportsInterface(type(IWittyPixelsToken).interfaceId)
                && _params.token.supportsInterface(type(IWittyPixelsTokenJackpots).interfaceId),
            "WittyPixelsTokenVault: uncompliant vault factory"
        );
        require(
            _params.tokenPixels > 0,
            "WittyPixelsTokenVault: no pixels"
        );

        // initialize openzeppelin's ERC20Upgradeable implementation
        __ERC20_init(_params.name, _params.symbol);

        // mint initial supply that will be owned by the contract itself
        _mint(address(this), _params.tokenPixels * 10 ** 18);
            
        // initialize clone storage:
        __storage.curator = _params.curator;
        __storage.parentToken = _params.token;
        __storage.parentTokenId = _params.tokenId;
        __storage.stats.totalPixels = _params.tokenPixels;
        _setAuctionSettings(_params.settings);
    }


    // ================================================================================================================
    // --- Internal virtual methods -----------------------------------------------------------------------------------

    function _afterCloning(address _newInstance, bytes memory _initdata)
        virtual internal
        returns (ITokenVaultWitnet)
    {
        Clonable(_newInstance).initializeClone(_initdata);
        return ITokenVaultWitnet(_newInstance);
    }

    function _setAuctionSettings(bytes memory _bytes) virtual internal {
        // decode dutch auction settings:
        IWittyPixelsTokenVaultAuctionDutch.Settings memory _settings = abi.decode(
            _bytes,
            (IWittyPixelsTokenVaultAuctionDutch.Settings)
        );
        // verify settings:
        require(
            _settings.startingPrice >= _settings.reservePrice
                && _settings.deltaPrice <= (_settings.startingPrice - _settings.reservePrice)
                && _settings.deltaSeconds > 0
                && _settings.startingPrice > 0
            , "WittyPixelsTokenVault: bad settings"
        );
        // update storage:
        __storage.settings = _settings;
        emit AuctionSettings(msg.sender, _bytes);
    }
}