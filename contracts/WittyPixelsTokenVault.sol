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

    WittyPixels.TokenVaultStorage internal __storage;

    modifier initialized {
        require(
            __storage.curator != address(0),
            "WittyPixelsTokenVault: not yet initialized"
        );
        _;
    }

    modifier notSoldOut {
        require(
            !soldOut(),
            "WittyPixelsTokenVault: sold out"
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

    modifier randomized {
        require(
            isRandomized(),
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
            || _interfaceId == type(OwnableUpgradeable).interfaceId
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
        returns (address)
    {
        return __storage.curator;
    }

    /// @notice Mint ERC-20 tokens, ergo token ownership, by providing ownership deeds.
    function redeem(bytes calldata _deedsdata)
        virtual override
        public
        initialized
        nonReentrant
        notSoldOut
    {
        WittyPixels.TokenVaultOwnershipDeeds memory _deeds = abi.decode(
            _deedsdata,
            (WittyPixels.TokenVaultOwnershipDeeds)
        );
        // first: verify signature
        bytes32 _deedshash = keccak256(abi.encode(
            _deeds.parentToken,
            _deeds.parentTokenId,
            _deeds.playerAddress,
            _deeds.playerIndex,
            _deeds.playerScore,
            _deeds.playerScoreProof
        ));
        require(
            WittyPixels.recoverAddr(_deedshash, _deeds.signature) == __storage.curator,
            "WittyPixelsTokenVault: bad signature"
        );
        // second: verify intrinsicals
        require(
            _deeds.parentToken == __storage.parentToken
                && _deeds.parentTokenId == __storage.parentTokenId
            , "WittyPixelsTokenVault: bad token"
        );
        require(
            !__storage.mints[_deeds.playerIndex],
            "WittyPixelsTokenVault: already minted"
        );
        require(
            __storage.totalScore + _deeds.playerScore <= __storage.totalSupply,
            "WittyPixelsTokenVault: overbooking :/"
        );
        // third: verify player score proof
        IWittyPixelsToken(_deeds.parentToken).verifyTokenPlayerScore(
            _deeds.parentTokenId,
            _deeds.playerIndex,
            _deeds.playerScore,
            _deeds.playerScoreProof
        );
        // fourth: update storage:
        __storage.totalScore += _deeds.playerScore;
        __storage.mints[_deeds.playerIndex] = true;
        __storage.members.push(_deeds.playerAddress);
        // fifth: no actual mint, but transfer from sovereign treasury
        _transfer(
            address(this),
            _deeds.playerAddress,
            _deeds.playerScore
        );
    }

    /// @notice Returns whether this NFT vault has already been sold out. 
    function soldOut()
        override
        public view
        returns (bool)
    {
        return IERC721(__storage.parentToken).ownerOf(__storage.parentTokenId) != address(this);
    }

    /// @notice Withdraw paid value in proportion to number of shares.
    /// @dev Fails if not yet sold out. 
    function withdraw()
        virtual override
        public
        initialized
        returns (uint256 _withdrawn)
    {
        require(
            soldOut(),
            "WittyPixelsTokenVault: not sold out yet"
        );
        require(
            balanceOf(msg.sender) > 0,
            "WittyPixelsTokenVault: not a member"
        );
        require(
            __storage.withdrawals[msg.sender] == 0,
            "WittyPixelsTokenVault: already withdrawn"
        );
        _withdrawn = (__storage.finalPrice * balanceOf(msg.sender)) / __storage.totalSupply;
        require(
            address(this).balance >= _withdrawn,
            "WittyPixelsTokenVault: not enough balance"
        );
        __storage.withdrawals[msg.sender] = _withdrawn;
        payable(msg.sender).transfer(_withdrawn);
        emit Withdrawal(msg.sender, _withdrawn);
    }

    /// @notice Tells withdrawable amount in weis from the given address.
    /// @dev Returns 0 in all cases while not yet sold out. 
    function withdrawableFrom(address _from)
        virtual override
        public view
        returns (uint256)
    {
        if (soldOut()) {
            if (__storage.withdrawals[_from] == 0) {
                return (__storage.finalPrice * balanceOf(_from)) / __storage.totalSupply;
            }
        }
        return 0;
    }


    // ================================================================================================================
    // --- Implements ITokenVaultWitnet -------------------------------------------------------------------------------

    function cloneAndInitialize(bytes memory _initdata)
        virtual override
        external
        returns (ITokenVaultWitnet)
    {
        Clonable _instance = super.clone();
        _instance.initialize(_initdata);
        OwnableUpgradeable(address(_instance)).transferOwnership(msg.sender);
        return ITokenVaultWitnet(address(_instance));
    }

    function cloneDeterministicAndInitialize(bytes32 _salt, bytes memory _initdata)
        virtual override
        external
        returns (ITokenVaultWitnet)
    {
        Clonable _instance = super.cloneDeterministic(_salt);
        _instance.initialize(_initdata);
        OwnableUpgradeable(address(_instance)).transferOwnership(msg.sender);
        return ITokenVaultWitnet(address(_instance));
    }

    function getRandomizeBlock()
        override
        external view
        returns (uint256)
    {
        return __storage.witnetRandomnessBlock;
    }

    function isRandomized()
        override
        public view
        returns (bool)
    {
        return (
            __storage.witnetRandomnessBlock != 0
                && randomizer.isRandomized(__storage.witnetRandomnessBlock)
        );
    }

    function isRandomizing()
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
    // --- Implements 'IWittyPixelsTokenVaultAuctionDutch' ------------------------------------------------------------

    function totalScore()
        override
        external view
        returns (uint256)
    {
        return __storage.totalScore;
    }


    // ================================================================================================================
    // --- Implements 'IWittyPixelsTokenVaultAuctionDutch' ------------------------------------------------------------

    function afmijnen()
        override
        external payable
        initialized
        nonReentrant
        notSoldOut
    {
        // verify provided value is greater or equal to current price:
        uint256 _currentPrice = price();
        require(
            msg.value >= _currentPrice,
            "WittyPixelsTokenVault: low value"
        );

        // safely transfer parent token id ownership to the bidder:
        IERC721(__storage.parentToken).safeTransferFrom(
            address(this),
            msg.sender,
            __storage.parentTokenId
        );
        
        // transfer back unused funds if `msg.value` was higher than current price:
        if (msg.value > _currentPrice) {
            payable(msg.sender).transfer(msg.value - _currentPrice);
        }
    }

    function auctioning()
        virtual override
        public view
        returns (bool)
    {
        uint _startingBlock = __storage.settings.startingBlock;
        return (
            _startingBlock != 0
                && block.number >= __storage.settings.startingBlock
                && !soldOut()
        );
    }

    function price()
        virtual override
        public view
        initialized
        returns (uint256)
    {
        IWittyPixelsTokenVaultAuctionDutch.Settings memory _settings = __storage.settings;
        if (block.number >= _settings.startingBlock) {
            if (__storage.finalPrice == 0) {
                uint _diffBlocks = block.number - _settings.startingBlock;
                uint _priceRange = _settings.startingPrice - _settings.reservePrice;
                uint _round = _diffBlocks / _settings.roundBlocks;
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

    function nextRoundBlock()
        override
        external view
        initialized
        returns (uint256)
    {
        IWittyPixelsTokenVaultAuctionDutch.Settings memory _settings = __storage.settings;
        if (block.number >= _settings.startingBlock) {
            uint _diffBlocks = block.number - _settings.startingBlock;
            uint _round = _diffBlocks / _settings.roundBlocks;
            return (
                _settings.startingBlock
                    + _settings.roundBlocks * (_round + 1)
            );
        } else {
            return _settings.startingBlock;
        }
    }

    function setDutchAuction(bytes memory _settings)
        override
        external
        onlyCurator
        notSoldOut
    {
        _setSettings(_settings);
    }
    
    function settings()
        override
        external view
        initialized
        returns (IWittyPixelsTokenVaultAuctionDutch.Settings memory)
    {
        return __storage.settings;
    }
    
    
    // ================================================================================================================
    // --- Implements 'IWittyPixelsTokenVaultJackpots' ---------------------------------------------------------------------

    function claimJackpot()
        override
        external
        randomized
        nonReentrant
        returns (uint256)
    {
        WittyPixels.TokenVaultJackpotWinner storage __winner = __storage.winners[msg.sender];
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
        initialized
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
        initialized
        returns (
            uint256 _index,
            address _sponsor,
            uint256 _value,
            string memory _text
        )
    {
        WittyPixels.TokenVaultJackpotWinner storage __winner = __storage.winners[_winner];
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
        return __storage.members.length;
    }

    function getJackpotsContestantsAddresses(uint _offset, uint _size)
        override
        external view
        returns (address[] memory _addrs)
    {
        require(
            _offset + _size <= __storage.members.length,
            "WittyPixelsTokenVault: out of range"
        );
        _addrs = new address[](_size);
        address[] storage __members = __storage.members;
        for (uint _i = 0; _i < _size; _i ++) {
            _addrs[_i] = __members[_offset + _i];
        }
    }

    function getJackpotsCount()
        override
        public view
        initialized
        returns (uint256)
    {
        return IWittyPixelsTokenJackpots(__storage.parentToken).getTokenJackpotsCount(
            __storage.parentTokenId
        );
    }
    
    function getJackpotsTotalValue()
        override
        external view
        initialized
        returns (uint256)
    {
        return IWittyPixelsTokenJackpots(__storage.parentToken).getTokenJackpotsTotalValue(
            __storage.parentTokenId
        );
    }

    function randomizeWinners()
        override 
        external payable
        initialized
        nonReentrant
        // TODO: onlyCurator?
    {
        require(
            block.number >= __storage.settings.startingBlock,
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
            __storage.members.length >= getJackpotsCount(),
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
        // TODO: onlyCurator?
    {
        require(
            isRandomizing(),
            "WittyPixelsTokenVault: not randomizing"
        );
        bytes32 _randomness = randomizer.getRandomnessAfter(__storage.witnetRandomnessBlock);
        address[] storage __members = __storage.members;        
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
            __storage.winners[_winnerAddr] = WittyPixels.TokenVaultJackpotWinner({
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

    /// Initialize storage-context when invoked as delegatecall. 
    /// @dev Must fail when trying to initialize same instance more than once.
    function initialize(bytes memory _initBytes) 
        public
        virtual override
        initializer // => ensure a clone can only be initialized once
        onlyDelegateCalls // => we don't need the logic base contract to be ever initialized
    {   
        super.initialize(_initBytes);

        // decode and validate initialization parameters:
        WittyPixels.TokenVaultInitParams memory _params = abi.decode(
            _initBytes,
            (WittyPixels.TokenVaultInitParams)
        );
        require(
            _params.curator != address(0),
            "WittyPixelsTokenVault: no curator"
        );
        require(
            msg.sender.supportsInterface(type(IWittyPixelsToken).interfaceId)
                && msg.sender.supportsInterface(type(IWittyPixelsTokenJackpots).interfaceId),
            "WittyPixelsTokenVault: uncompliant vault factory"
        );

        // initialize openzeppelin's ERC20Upgradeable implementation
        __ERC20_init(_params.name, _params.symbol);

        // mint initial supply that will be owned by the contract itself
        _mint(address(this), _params.supply);
            
        // initialize clone storage:
        __storage.curator = _params.curator;
        __storage.parentToken = msg.sender;
        __storage.parentTokenId = _params.tokenId;
        _setSettings(_params.settings);
    }


    // ================================================================================================================
    // --- Internal virtual methods -----------------------------------------------------------------------------------

    function _setSettings(bytes memory _bytes) virtual internal {
        // decode dutch auction settings:
        IWittyPixelsTokenVaultAuctionDutch.Settings memory _settings = abi.decode(
            _bytes,
            (IWittyPixelsTokenVaultAuctionDutch.Settings)
        );
        // verify settings:
        require(
            _settings.startingPrice >= _settings.reservePrice
                && _settings.deltaPrice <= (_settings.startingPrice - _settings.reservePrice)
                && _settings.roundBlocks > 0
                && _settings.startingBlock > block.number
                && _settings.startingPrice > 0
            , "WittyPixelsTokenVault: bad settings"
        );
        // update storage:
        __storage.settings = _settings;
        emit SettingsChanged(msg.sender, _settings);
    }

}