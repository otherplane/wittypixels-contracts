// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import "witnet-solidity-bridge/contracts/impls/WitnetProxy.sol";
import "witnet-solidity-bridge/contracts/interfaces/IWitnetRequest.sol";
import "witnet-solidity-bridge/contracts/patterns/Clonable.sol";

import "./interfaces/ITokenVaultFactory.sol";
import "./interfaces/IWittyPixelsToken.sol";
import "./interfaces/IWittyPixelsTokenAdmin.sol";
import "./interfaces/IWittyPixelsTokenJackpots.sol";

import "./patterns/WittyPixelsUpgradeableBase.sol";

/// @title  Witty Pixels NFT - ERC721 token contract
/// @author Otherplane Labs Ltd., 2022
/// @dev    This contract needs to be proxified.
contract WittyPixelsToken
    is
        ERC721Upgradeable,
        ITokenVaultFactory,
        IWittyPixelsToken,
        IWittyPixelsTokenAdmin,
        IWittyPixelsTokenJackpots,
        WittyPixelsUpgradeableBase
{
    using ERC165Checker for address;
    using Strings for uint256;
    using WittyPixels for bytes;
    using WittyPixels for bytes32[];
    using WittyPixels for WittyPixels.ERC721Token;

    WitnetRequestTemplate immutable public witnetRequestImageDigest;
    WitnetRequestTemplate immutable public witnetRequestTokenStats;

    WittyPixels.TokenStorage internal __storage;

    modifier initialized {
        require(
            __storage.implementation != address(0),
            "WittyPixelsToken: not initialized"
        );
        _;
    }

    modifier onlyTokenSponsors(uint256 _tokenId) {
        require(
            __storage.sponsors[_tokenId].jackpots[msg.sender].authorized,
            "WittyPixelsToken: not authorized"
        );
        _;
    }

    modifier tokenExists(uint256 _tokenId) {
        require(
            _exists(_tokenId),
            "WittyPixelsToken: unknown token"
        );
        _;
    }

    modifier tokenInStatus(uint256 _tokenId, WittyPixels.ERC721TokenStatus _status) {
        require(getTokenStatus(_tokenId) == _status, "WittyPixelsToken: bad mood");
        _;
    }

    constructor(
            WitnetRequestTemplate _requestImageDigest,
            WitnetRequestTemplate _requestTokenStats,
            bool _upgradable,
            bytes32 _version
        )
        WittyPixelsUpgradeableBase(
            _upgradable,
            _version,
            "art.wittypixels.token"
        )
    {
        assert(address(_requestImageDigest) != address(0));
        assert(address(_requestTokenStats) != address(0));
        witnetRequestImageDigest = _requestImageDigest;
        witnetRequestTokenStats = _requestTokenStats;
    }


    // ================================================================================================================
    // --- Overrides IERC165 interface --------------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId)
      public view
      virtual override
      onlyDelegateCalls
      returns (bool)
    {
        return _interfaceId == type(ITokenVaultFactory).interfaceId
            || _interfaceId == type(IWittyPixelsToken).interfaceId
            || _interfaceId == type(IWittyPixelsTokenJackpots).interfaceId
            || ERC721Upgradeable.supportsInterface(_interfaceId)
            || _interfaceId == type(Ownable2StepUpgradeable).interfaceId
            || _interfaceId == type(Upgradeable).interfaceId
            || _interfaceId == type(IWittyPixelsTokenAdmin).interfaceId
        ;
    }


    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// Initialize storage-context when invoked as delegatecall. 
    /// @dev Must fail when trying to initialize same instance more than once.
    function initialize(bytes memory _initdata) 
        public
        virtual override
        onlyDelegateCalls // => we don't want the logic base contract to be ever initialized
    {
        address _implementation = __storage.implementation;
        if (_implementation == address(0)) {
            // a proxy is being initilized for the first time ...
            _initializeProxy(_initdata);
        }
        else {
            // a proxy is being upgraded ...
            // only the proxy's owner can upgrade it
            require(
                msg.sender == owner(),
                "WittyPixelsToken: not the owner"
            );
            // the implementation cannot be upgraded more than once, though
            require(
                _implementation != base(),
                "WittyPixelsToken: already initialized"
            );
            emit Upgraded(
                msg.sender,
                base(),
                codehash(),
                version()
            );
        }
        __storage.implementation = base();    
    }

    
    // ================================================================================================================
    // --- Overrides 'ERC721TokenMetadata' overriden functions --------------------------------------------------------

    function tokenURI(uint256 _tokenId)
        public view
        virtual override
        tokenExists(_tokenId)
        returns (string memory)
    {
        return string(abi.encodePacked(
            baseURI(),
            "metadata/",
            _tokenId.toString()
        ));
    }


    // ================================================================================================================
    // --- Implementation of 'ITokenVaultFactory' ---------------------------------------------------------------------

    /// @notice Fractionalize given token by transferring ownership to new instance of ERC-20 ERC721Token Vault. 
    /// @dev This vault factory is only intended for fractionalizing its own tokens.
    function fractionalize(address, uint256, bytes memory)
        external pure
        override
        returns (ITokenVault)
    {
        revert("WittyPixelsToken: not implemented");
    }

    /// @notice Fractionalize given token by transferring ownership to new instance
    /// @notice of the ERC721 Token Vault prototype contract. 
    /// @dev Token must be in 'Minting' status and involved Witnet requests successfully solved.
    /// @param _tokenId ERC721Token identifier within that collection.
    /// @param _tokenVaultSettings Extra settings to be passed when initializing the token vault contract.
    function fractionalize(
            uint256 _tokenId,
            bytes   memory _tokenVaultSettings
        )
        external
        tokenInStatus(_tokenId, WittyPixels.ERC721TokenStatus.Minting)
        onlyOwner
        returns (ITokenVault)
    {
        WittyPixels.ERC721Token storage __token = __storage.items[_tokenId];
        WittyPixels.ERC721TokenWitnetRequests storage __requests = __storage.witnetRequests[_tokenId];
        
        // Check there's a token vault prototype set:
        require(
            address(__storage.tokenVaultPrototype) != address(0),
            "WittyPixelsToken: no token vault prototype"
        );

        // Check the image URI actually exists, and store the image digest:
        try __requests.imageDigest.lastValue()
            returns (bytes memory, bytes32 _txhash, uint256 _txts)
        {
            require(
                _txts >= __token.birthTs,
                "WittyPixelsToken: anachronic image proof"
            );
            __token.imageWitnetTxHash = _txhash;
        }
        catch Error(string memory _reason) {
            revert(_reason);
        }
        catch (bytes memory) {
            revert("WittyPixelsToken: cannot deserialize image proof");
        }

        // Check the token roots reported by Witnet match the rest of token's
        // metadata, including the image digest:
        try __requests.tokenStats.lastValue()
            returns (bytes memory _stats, bytes32 _txhash, uint256 _txts)
        {
            require(
                _txts >= __token.birthTs,
                "WittyPixelsToken: anachronic stats proof"
            );
            __token.statsWitnetTxHash = _txhash;
            __token.theStats = abi.decode(_stats, (WittyPixels.ERC721TokenStats));
        }
        catch Error(string memory _reason) {
            revert(_reason);
        }
        catch (bytes memory) {
            revert("WittyPixelsToken: cannot deserialize stats proof");
        }
        
        // Clone the token vault prototype and initialize the cloned instance:
        IWittyPixelsTokenVault _tokenVault = IWittyPixelsTokenVault(address(
            __storage.tokenVaultPrototype.cloneAndInitialize(abi.encode(
                WittyPixels.TokenVaultInitParams({
                    curator: msg.sender,
                    name: string(abi.encode(name(), " #", _tokenId.toString())),
                    symbol: symbol(),
                    settings: _tokenVaultSettings,
                    token: address(this),
                    tokenId: _tokenId,
                    totalPixels: __token.theStats.totalPixels
                })
            ))
        ));

        // Store token vault contract:
        uint _tokenVaultIndex = ++ __storage.totalTokenVaults;
        __storage.vaults[_tokenVaultIndex] = _tokenVault;

        // Update reference to token vault contract in token's metadata
        __storage.tokenVaultIndex[_tokenId] = _tokenVaultIndex;

        // Mint the actual ERC-721 token and set the just created vault contract as first owner ever:
        _mint(address(_tokenVault), _tokenId);
        
        // Increment total supply:
        __storage.totalSupply ++;

        // Emits event
        emit Fractionalized(
            msg.sender,
            address(this),
            _tokenId,
            _tokenVaultIndex,
            address(_tokenVault)
        );

        return ITokenVault(address(_tokenVault));
    }

    /// @notice Gets data of a token vault created by this factory.
    function getTokenVaultByIndex(uint256 index)
        public view
        override
        returns (ITokenVault)
    {
        if (index < __storage.totalTokenVaults) {
            return ITokenVault(__storage.vaults[index]);
        } else {
            return ITokenVault(address(0));
        }
    }
    
    /// @notice Gets current status of token vault created by this factory.
    function getTokenVaultStatusByIndex(uint256 index)
        external view
        returns (TokenVaultStatus)
    {
        ITokenVault _vault = getTokenVaultByIndex(index);
        if (address(_vault) != address(0)) {
            try _vault.soldOut() returns (bool _soldOut) {
                return (_soldOut
                    ? ITokenVaultFactory.TokenVaultStatus.SoldOut
                    : ITokenVaultFactory.TokenVaultStatus.Active
                );
            } catch {
                return ITokenVaultFactory.TokenVaultStatus.Deleted;
            }
        } else {
            return ITokenVaultFactory.TokenVaultStatus.Unknown;
        }
    }

    /// @notice Returns token vault prototype being instantiated when fractionalizing. 
    /// @dev If destructible, it must be owned by this contract.
    function tokenVaultPrototype()
        external view
        override
        returns (ITokenVault)
    {
        return ITokenVault(__storage.tokenVaultPrototype);
    }

    /// @notice Returns number of vaults created so far.
    function totalTokenVaults()
        external view
        override 
        returns (uint256)
    {
        return __storage.totalTokenVaults;
    }


    // ================================================================================================================
    // --- Implementation of 'IWittyPixelsToken' ----------------------------------------------------------------------

    /// @notice Returns base URI for all tokens of this collection.
    function baseURI()
        override public view
        initialized
        returns (string memory)
    {
        return __storage.baseURI;
    }

    /// @notice Gets token's current status.
    function getTokenStatus(uint256 _tokenId)
        override public view
        initialized
        returns (WittyPixels.ERC721TokenStatus)
    {
        if (_tokenId <= __storage.totalSupply) {
            uint _vaultIndex = __storage.tokenVaultIndex[_tokenId];
            if (
                _vaultIndex > 0
                    && ownerOf(_tokenId) != address(__storage.vaults[_vaultIndex])
            ) {
                return WittyPixels.ERC721TokenStatus.SoldOut;
            } else {
                return WittyPixels.ERC721TokenStatus.Fractionalized;
            }
        } else {
            WittyPixels.ERC721Token storage __token = __storage.items[_tokenId];
            if (__token.birthTs > 0) {
                return WittyPixels.ERC721TokenStatus.Minting;
            } else if (bytes(__token.theEvent.name).length > 0) {
                return WittyPixels.ERC721TokenStatus.Launching;
            } else {
                return WittyPixels.ERC721TokenStatus.Void;
            }
        }
    }

    function getTokenStatusString(uint256 _tokenId)
        override external view
        initialized
        returns (string memory)
    {
        WittyPixels.ERC721TokenStatus _status = getTokenStatus(_tokenId);
        if (_status == WittyPixels.ERC721TokenStatus.SoldOut) {
            return "SoldOut";
        } else if (_status == WittyPixels.ERC721TokenStatus.Fractionalized) {
            return "Fractionalized";
        } else if (_status == WittyPixels.ERC721TokenStatus.Minting) {
            return "Minting";
        } else if (_status == WittyPixels.ERC721TokenStatus.Launching) {
            return "Launching";
        } else {
            return "Void";
        }
    }

    /// @notice Gets token ERC721Token.
    function getTokenMetadata(uint256 _tokenId)
        external view
        override
        initialized
        returns (WittyPixels.ERC721Token memory)
    {
        return __storage.items[_tokenId];
    }
    
    /// @notice Gets token vault contract, if any.
    function getTokenVault(uint256 _tokenId)
        public view
        override
        tokenExists(_tokenId)
        returns (ITokenVaultWitnet)
    {
        return __storage.vaults[
            __storage.tokenVaultIndex[_tokenId]
        ];
    }

    /// @notice Gets set of immutable contracts that were used for
    /// @notice retrieving token's metadata and image digest from 
    /// @notice the Witnet oracle.
    function getTokenWitnetRequests(uint256 _tokenId)
        external view
        override
        initialized
        returns (WittyPixels.ERC721TokenWitnetRequests memory)
    {
        return __storage.witnetRequests[_tokenId];
    }

    /// @notice Returns image URI of given token.
    function imageURI(uint256 _tokenId)
        override
        external view 
        initialized// tokenExists(_tokenId)
        returns (string memory)
    {
        return __storage.items[_tokenId].imageURI;
    }

    /// @notice Serialize token ERC721Token to JSON string.
    function metadata(uint256 _tokenId)
        external view 
        override
        tokenExists(_tokenId)
        returns (string memory)
    {
        return __storage.items[_tokenId].toJSON();
    }

    /// @notice Returns total number of WittyPixels tokens that have been minted so far.
    function totalSupply()
        external view
        override
        returns (uint256)
    {
        return __storage.totalSupply;
    }

    function verifyTokenPlayerScore(
            uint256 _tokenId,
            uint256 _playerIndex,
            uint256 _playerScore,
            bytes32[] memory _proof
        )
        external view
        override
        tokenExists(_tokenId)
        returns (bool)
    {
        WittyPixels.ERC721Token storage __token = __storage.items[_tokenId];
        return (
            _playerIndex < __token.theStats.totalPlayers
                && _proof.merkle(keccak256(abi.encode(
                    _playerIndex,
                    _playerScore
                ))) == __token.theStats.playersRoot
        );
    }


    // ================================================================================================================
    // --- Implementation of 'IWittyPixelsTokenAdmin' -----------------------------------------------------------------

    function launch(WittyPixels.ERC721TokenEvent calldata _theEvent)
        override external
        onlyOwner
        returns (uint256 _tokenId)
    {
        _tokenId = __storage.totalSupply + 1;
        WittyPixels.ERC721TokenStatus _status = getTokenStatus(_tokenId);
        require(
            _status == WittyPixels.ERC721TokenStatus.Void
                || _status == WittyPixels.ERC721TokenStatus.Launching,
            "WittyPixelsToken: bad mood"
        );
        // Check the event data:
        require(
            bytes(_theEvent.name).length > 0
                && bytes(_theEvent.venue).length > 0,
            "WittyPixelsToken: event empty strings"
        );
        require(
            _theEvent.startTs <= _theEvent.endTs,
            "WittyPixelsToken: event bad timestamps"
        );
        // Change token status:
        __storage.items[_tokenId].theEvent = _theEvent;
    }
    
    function premint(
            uint256 _tokenId,
            bytes32 _witnetSlaHash
        )
        external payable
        override
        onlyOwner /* as long as imageURI ends up to be unrelated to baseURI */  
        nonReentrant
        initialized
    {
        WittyPixels.ERC721TokenStatus _status = getTokenStatus(_tokenId);
        require(
            _status == WittyPixels.ERC721TokenStatus.Launching
                || _status == WittyPixels.ERC721TokenStatus.Minting,
            "WittyPixelsToken: bad mood"
        );        
        WittyPixels.ERC721Token storage __token = __storage.items[_tokenId];
        require(
            block.timestamp >= __token.theEvent.endTs,
            "WittyPixelsToken: the event is not over yet"
        );
        
        // Set the token's image uri and inception timestamp
        string memory _imageuri = _imageURI(_tokenId);
        {
            __token.birthTs = block.timestamp;
            __token.imageURI = _imageuri;
        }

        uint _usedFunds; WitnetRequestTemplate _request;
        WittyPixels.ERC721TokenWitnetRequests storage __requests = __storage.witnetRequests[_tokenId];        
        // Ask Witnet to confirm the token's image URI actually exists:
        {
            string[][] memory _args = new string[][](1);
            _args[0] = new string[](1);
            _args[0][0] = _imageuri;
            _request = witnetRequestImageDigest.clone(
                abi.encode(WitnetRequestTemplate.InitData({
                    args: _args,
                    slaHash: _witnetSlaHash
                }))
            );
            _usedFunds += _request.update{value: msg.value / 2}();
            __requests.imageDigest = _request;
        }

        // Ask Witnet to retrieve token's metadata stats from the token base uri provider:
        {
            string[][] memory _args = new string[][](1);
            _args[0] = new string[](1);
            _args[0][0] = string(abi.encodePacked(
                bytes(baseURI()),
                "stats/",
                _tokenId.toString()                
            ));
            _request = witnetRequestTokenStats.clone(
                abi.encode(WitnetRequestTemplate.InitData({
                    args: _args,
                    slaHash: _witnetSlaHash
                }))
            );
            _usedFunds += _request.update{value: msg.value / 2}();
            __requests.tokenStats = _request;
        }

        // Transfer back unused funds, if any:
        if (_usedFunds < msg.value) {
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }
        
        // Emit event:
        emit Minting(_tokenId, _imageuri, _witnetSlaHash);
    }

    /// @notice Sets collection's base URI.
    function setBaseURI(string calldata _uri)
        external 
        override
        onlyOwner 
    {
        __storage.baseURI = WittyPixels.checkBaseURI(_uri);
    }

    /// @notice Update sponsors access-list by adding new players. 
    /// @dev If already included in the list, names could still be updated.
    function setTokenSponsors(
            uint256 _tokenId,
            address[] calldata _addresses,
            string[] calldata _texts
        )
        external
        override
        onlyOwner
    {
        assert(_addresses.length == _texts.length);
        // tokenId can only be current totalSupply + 1: not minted, and not in the process of being minted
        require(
            _tokenId == __storage.totalSupply + 1,
            "WittyPixelsToken: invalid token"
        );
        // add new sponsor addresses to the access list if not yet there:
        WittyPixels.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
        for (uint _i = 0; _i < _addresses.length; _i ++) {
            address _addr = _addresses[_i];
            if (!__sponsors.jackpots[_addr].authorized) {
                __sponsors.addresses.push(_addr);
                __sponsors.jackpots[_addr].authorized = true;
                emit NewTokenSponsor(
                    _tokenId,
                    __sponsors.addresses.length - 1,
                    _addr
                );
            }
            // update sponsor name in all cases
            __sponsors.jackpots[_addr].text = _texts[_i];
        }
    }

    /// @notice Vault logic contract to be used in next calls to `fractionalize(..)`. 
    /// @dev Prototype ownership needs to have been previously transferred to this contract.
    function setTokenVaultPrototype(address _prototype)
        external
        override
        onlyOwner
    {
        _verifyPrototypeCompliance(_prototype);
        __storage.tokenVaultPrototype = IWittyPixelsTokenVault(_prototype);
    }


    // ================================================================================================================
    // --- Implementation of 'IWittyPixelsTokenJackpots' --------------------------------------------------------------

    function getTokenJackpotByIndex(
            uint256 _tokenId,
            uint256 _index
        )
        external view
        override
        returns (
            address _sponsor,
            address _winner,
            uint256 _value,
            string memory _text
        )
    {
        WittyPixels.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
        if (_index < __sponsors.addresses.length) {
            _sponsor = __sponsors.addresses[_index];
            WittyPixels.ERC721TokenJackpot storage __jackpot = __sponsors.jackpots[_sponsor];
            _text = __jackpot.text;
            _value = __jackpot.value;
            _winner = __jackpot.winner;
        }
    }

    function getTokenJackpotsCount(uint256 _tokenId)
        external view
        override
        returns (uint256)
    {
        return __storage.sponsors[_tokenId].addresses.length;
    }

    function getTokenJackpotsTotalValue(uint256 _tokenId)
        external view
        override
        returns (uint256)
    {
        return __storage.sponsors[_tokenId].totalJackpots;
    }

    function sponsoriseToken(uint256 _tokenId)
        external payable
        override
        onlyTokenSponsors(_tokenId)
        tokenInStatus(_tokenId, WittyPixels.ERC721TokenStatus.Void)
    {
        WittyPixels.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
        __sponsors.jackpots[msg.sender].value += msg.value;
        __sponsors.totalJackpots += msg.value;
    }

    function transferTokenJackpot(
            uint256 _tokenId,
            uint256 _index,
            address payable _winner
        )
        external
        override
        tokenExists(_tokenId)
        returns (uint256 _value)
    {
        require(
            getTokenVault(_tokenId).parentToken() == address(this),
            "WittyPixelsToken: unauthorized"
        );
        assert(_winner != address(0));
        WittyPixels.ERC721TokenSponsors storage __sponsors = __storage.sponsors[_tokenId];
        assert(_index < __sponsors.addresses.length);
        address _sponsor = __sponsors.addresses[_index];
        WittyPixels.ERC721TokenJackpot storage __jackpot = __sponsors.jackpots[_sponsor];
        require(
            __jackpot.winner == address(0), "WittyPixelsToken: already claimed"
        );
        _value = __jackpot.value;
        require(
            _value > 0,
            "WittyPixelsToken: no jackpot value"
        );
        require(
            _value < address(this).balance,
            "WittyPixelsToken: not enough balance"
        );
        __jackpot.value = 0;
        __jackpot.winner = _winner;
        _winner.transfer(_value);
        emit Jackpot(
            _tokenId, 
            _index,
            _winner,
            _value
        );
    }


    // ================================================================================================================
    // --- Internal virtual methods -----------------------------------------------------------------------------------

    function _imageURI(uint256 _tokenId)
        virtual internal view
        initialized
        returns (string memory)
    {
        return string(abi.encodePacked(
            __storage.baseURI,
            "image/",
            _tokenId.toString()
        ));
    }

    function _initializeProxy(bytes memory _initdata)
        virtual internal
        initializer 
    {
        // As for OpenZeppelin's ERC721Upgradeable implementation,
        // name and symbol can only be initialized once;
        // as for an upgradable (and proxiable) contract as this one,
        // the setting of name and symbol needs to be invoked in
        // a dedicated and unique 'initializer' method, other from the
        // `initialize(bytes)` method that gets called every time
        // a proxy contract is upgraded.

        // read and set ERC721 initialization parameters
        WittyPixels.TokenInitParams memory _params = abi.decode(
            _initdata,
            (WittyPixels.TokenInitParams)
        );
        __storage.baseURI = WittyPixels.checkBaseURI(_params.baseURI);
        __ERC721_init(
            _params.name,
            _params.symbol
        );        
        __Ownable2Step_init();
        __ReentrancyGuard_init();
    }

    function _verifyPrototypeCompliance(address _prototype) virtual internal view {
        require(
            _prototype.supportsInterface(type(IWittyPixelsTokenVault).interfaceId),
            "WittyPixelsToken: uncompliant prototype"
        );
    }

}