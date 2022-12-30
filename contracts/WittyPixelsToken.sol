// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "witnet-solidity-bridge/contracts/interfaces/IWitnetRequest.sol";
import "witnet-solidity-bridge/contracts/patterns/Clonable.sol";

import "./impls/WittyPixelsUpgradableBase.sol";
import "./interfaces/ITokenVaultFactory.sol";
import "./interfaces/IWittyPixels.sol";
import "./interfaces/IWittyPixelsAdmin.sol";

/// @title  Witty Pixels NFT - ERC721 Token contract
/// @author Otherplane Labs Ltd., 2022
/// @dev    https://github.com/guidiaz
contract WittyPixelsToken
    is
        ERC721,
        ITokenVaultFactory,
        IWittyPixels,
        IWittyPixelsAdmin,
        WittyPixelsUpgradableBase
{
    using ERC165Checker for address;
    using Strings for uint256;
    using WittyPixels for bytes;
    using WittyPixels for bytes32[];
    using WittyPixels for WittyPixels.TokenMetadata;

    WitnetRequestTemplate immutable public witnetRequestImageDigest;
    WitnetRequestTemplate immutable public witnetRequestTokenRoots;
    WittyPixels.TokenStorage internal __storage;

    modifier tokenExists(uint256 _tokenId) {
        require(
            _exists(_tokenId),
            "WittyPixelsToken: unknown token"
        );
        _;
    }

    constructor(
            WitnetRequestTemplate _requestImageDigest,
            WitnetRequestTemplate _requestTokenRoots,
            string memory _baseuri,
            bool _upgradable,
            bytes32 _version
        )
        ERC721("WittyPixels ", "WPX")
        WittyPixelsUpgradableBase(
            _upgradable,
            _version,
            "io.witnet.games.witty-pixels"
        )
    {
        assert(address(_requestImageDigest) != address(0));
        assert(address(_requestTokenRoots) != address(0));        
        __storage.baseURI = WittyPixels.checkBaseURI(_baseuri);
        witnetRequestImageDigest = _requestImageDigest;
        witnetRequestTokenRoots = _requestTokenRoots;
        
    }

    receive() external payable override {}

    // ================================================================================================================
    // --- Overrides IERC165 interface --------------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId)
      public view
      virtual override
      returns (bool)
    {
        return _interfaceId == type(ITokenVaultFactory).interfaceId
            || _interfaceId == type(IWittyPixelsAdmin).interfaceId
            || ERC721.supportsInterface(_interfaceId)
            || _interfaceId == type(Ownable).interfaceId
            || _interfaceId == type(Ownable2Step).interfaceId
            || _interfaceId == type(Upgradable).interfaceId
        ;
    }


    // ================================================================================================================
    // --- Overrides 'Ownable2Step' -----------------------------------------------------------------------------------

    /// Returns the address of the pending owner.
    function pendingOwner()
        public view
        virtual override
        returns (address)
    {
        return __storage.pendingOwner;
    }

    /// Returns the address of the current owner.
    function owner()
        public view
        virtual override
        returns (address)
    {
        return __storage.owner;
    }

    /// Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// @dev Can only be called by the current owner.
    function transferOwnership(address _newOwner)
        public
        virtual override
        onlyOwner
    {
        __storage.pendingOwner = _newOwner;
        emit OwnershipTransferStarted(owner(), _newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`_newOwner`) and deletes any pending owner.
    /// @dev Internal function without access restriction.
    function _transferOwnership(address _newOwner)
        internal
        virtual override
    {
        delete __storage.pendingOwner;
        address _oldOwner = owner();
        if (_newOwner != _oldOwner) {
            __storage.owner = _newOwner;
            emit OwnershipTransferred(_oldOwner, _newOwner);
        }
    }


    // ================================================================================================================
    // --- Overrides 'Upgradable' -------------------------------------------------------------------------------------

    /// Initialize storage-context when invoked as delegatecall. 
    /// @dev Must fail when trying to initialize same instance more than once.
    function initialize(bytes memory) 
        public
        virtual override
    {
        address _owner = __storage.owner;
        if (_owner == address(0)) {
            // set owner if none set yet
            _owner = msg.sender;
            __storage.owner = _owner;
        } else {
            // only owner can initialize:
            if (msg.sender != _owner) revert WittyPixelsUpgradableBase.OnlyOwner(_owner);
        }

        if (__storage.base != address(0)) {
            // current implementation cannot be initialized more than once:
            if(__storage.base == base()) revert WittyPixelsUpgradableBase.AlreadyInitialized(base());
        }        
        __storage.base = base();

        emit Upgraded(msg.sender, base(), codehash(), version());
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = __storage.owner;
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
        );
    }

    
    // ========================================================================
    // --- Overrides 'ERC721TokenMetadata' overriden functions ---------------------

    /// Pre-minting phase:
    /// api.wittypixels.art/metadata/chainid/tokenid    --> api-ethdenver23/metadata/chainid
    /// api.wittypixels.art/roots/chainid/tokenid              --> api-ethdenver23/image
    // {
    //     players: [
    //         { name: "name", score: 1234 },
    //     ],
    //     roots: {
    //         names: "0x",
    //         scores: "0x",
    //     }
    // }
    function tokenURI(uint256 _tokenId)
        public view
        virtual override
        tokenExists(_tokenId)
        returns (string memory)
    {
        return string(abi.encodePacked(
            baseURI(),
            "metadata/",
            block.chainid.toString(),
            "/",
            _tokenId.toString()
        ));
    }


    // ========================================================================
    // --- Implementation of 'ITokenVaultFactory' -----------------------------

    /// @notice Fractionalize given token by transferring ownership to new instance of ERC-20 Token Vault. 
    /// @dev This vault factory is only intended for fractionalizing its own tokens.
    function fractionalize(address, uint256, string memory, string memory, bytes memory)
        external pure
        override
        returns (ITokenVault)
    {
        revert("WittyPixelsToken: not implemented");
    }

    /// @notice Fractionalize given token by transferring ownership to new instance
    /// @notice of ERC-20 Token Vault. 
    /// @dev Caller must be the owner of specified token.
    /// @param _tokenId Token identifier within that collection.
    /// @param _tokenVaultName Name of the ERC-20 Token Vault to be created.
    /// @param _tokenVaultSymbol Symbol of the ERC-20 Token Vault to be created.
    /// @param _tokenVaultSettings Extra settings to be passed when initializing the token vault contract.
    function fractionalize(
            uint256 _tokenId,
            string  memory _tokenVaultName,
            string  memory _tokenVaultSymbol,
            bytes   memory _tokenVaultSettings
        )
        external
        tokenExists(_tokenId)
        returns (ITokenVault _tokenVault)
    {
        // check required conditions
        WittyPixels.TokenMetadata storage __token = __storage.items[_tokenId];
        require(
            address(__storage.tokenVaultPrototype) != address(0),
            "WittyPixelsToken: no token vault prototype"
        );
        require(
            ownerOf(_tokenId) == msg.sender,
            "WittyPixelsToken: not the token owner"
        );
        require(
            __storage.tokenVaultIndex[_tokenId] == 0,
            "WittyPixelsToken: already fractionalized"
        );
        
        // clone token vault prototype
        _tokenVault = ITokenVault(address(
            __storage.tokenVaultPrototype.clone()
        ));

        // initialize newly created token vault contract
        bytes memory _initData = abi.encode(WittyPixels.TokenVaultInitParams({
            curator: msg.sender,
            tokenId: _tokenId,
            erc20Supply:  __token.theStats.totalScore,
            erc20Name: _tokenVaultName,
            erc20Symbol: _tokenVaultSymbol,
            settings: _tokenVaultSettings
        }));
        Initializable(address(_tokenVault)).initialize(_initData);

        // store token vault contract
        uint _tokenVaultIndex = ++ __storage.totalTokenVaults;
        __storage.vaults[_tokenVaultIndex] = ITokenVaultWitnet(address(_tokenVault));

        // update reference to token vault contract in token's metadata
        __storage.tokenVaultIndex[_tokenId] = _tokenVaultIndex;

        // emits event
        emit Fractionalized(
            msg.sender,
            address(this),
            _tokenId,
            _tokenVaultIndex,
            address(_tokenVault)
        );
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


    // ========================================================================
    // --- Implementation of 'IWittyPixels' -----------------------------------

    /// @notice Returns base URI for all tokens of this collection.
    function baseURI()
        public view
        override
        returns (string memory)
    {
        return __storage.baseURI;
    }

    /// @notice Gets token's current status.
    function getTokenStatus(uint256 tokenId)
        public view
        override
        returns (WittyPixels.TokenStatus)
    {
        if (tokenId > __storage.totalSupply && tokenId > 0) {
            WittyPixels.TokenMetadata storage __metadata = __storage.items[tokenId];
            if (__metadata.block > 0) {
                uint _vaultIndex = __storage.tokenVaultIndex[tokenId];
                if (_vaultIndex > 0) {
                    if (ownerOf(tokenId) != address(__storage.vaults[_vaultIndex])) {
                        return WittyPixels.TokenStatus.SoldOut;
                    } else {
                        return WittyPixels.TokenStatus.Fractionalized;
                    }
                } else {
                    return WittyPixels.TokenStatus.Minted;
                }
            } else {
                return WittyPixels.TokenStatus.Minting;
            }
        } else {
            return WittyPixels.TokenStatus.Void;
        }
    }

    /// @notice Gets token TokenMetadata.
    function getTokenMetadata(uint256 _tokenId)
        external view
        override
        tokenExists(_tokenId)
        returns (WittyPixels.TokenMetadata memory)
    {
        return __storage.items[_tokenId];
    }
    
    /// @notice Gets token vault contract, if any.
    function getTokenVault(uint256 _tokenId)
        external view
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
        tokenExists(_tokenId)
        returns (WittyPixels.TokenWitnetRequests memory)
    {
        return __storage.witnetRequests[_tokenId];
    }

    /// @notice Serialize token TokenMetadata to JSON string.
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
        WittyPixels.TokenMetadata storage __metadata = __storage.items[_tokenId];
        return (
            _playerIndex < __metadata.theStats.totalPlayers
                && _proof.merkle(keccak256(abi.encode(
                    _playerIndex,
                    _playerScore
                ))) == __metadata.theRoots.scores
        );
    }

    function verifyTokenPlayerName(
            uint256 _tokenId,
            uint256 _playerIndex,
            string calldata _playerName,
            bytes32[] calldata _proof
        )
        external view
        override
        tokenExists(_tokenId)
        returns (bool)
    {
        WittyPixels.TokenMetadata storage __metadata = __storage.items[_tokenId];
        return (
            _playerIndex < __metadata.theStats.totalPlayers
                && _proof.merkle(keccak256(abi.encode(
                    _playerIndex,
                    _playerName
                ))) == __metadata.theRoots.scores
        );
    }


    // ========================================================================
    // --- Implementation of 'IWittyPixelsAdmin' ------------------------------

    function premint(
            uint256 _tokenId,
            string calldata _imageURI,
            bytes32 _tallyHash, // TODO: should it be inherent to WitnetRequestTemplate?
            bytes32 _slaHash
        )
        external payable
        override
        onlyOwner
        nonReentrant
    {
        WittyPixels.TokenStatus _status = getTokenStatus(_tokenId);
        require(
            _status == WittyPixels.TokenStatus.Void && _tokenId == __storage.totalSupply + 1
                || _status == WittyPixels.TokenStatus.Minting,
            "WittyPixelsToken: bad mood"
        );
        require(
            bytes(_imageURI).length > 0,
            "WittyPixelsToken: no image URI"
        );        
        if (_status == WittyPixels.TokenStatus.Void) {
            // increase total supply only upon first premint of this token id:
            __storage.totalSupply ++;
        }
        WittyPixels.TokenMetadata storage __metadata = __storage.items[_tokenId];        
        WittyPixels.TokenWitnetRequests storage __requests = __storage.witnetRequests[_tokenId];
        
        // Ask Witnet to confirm the token's image URI actually exists:
        uint _usedFunds;
        {
            string[][] memory _args = new string[][](1);
            _args[0] = new string[](1);
            _args[0][0] = _imageURI;
            __requests.imageDigest = WitnetRequestTemplate(payable(address(witnetRequestImageDigest.clone())));
            __requests.imageDigest.initialize(abi.encode(WitnetRequestTemplate.InitData({
                args: _args,
                tallyHash: _tallyHash,
                slaHash: _slaHash,
                resultMaxSize: 0
            })));
            __metadata.imageURI = _imageURI;
            _usedFunds += __requests.imageDigest.post{value: msg.value}();
        }

        // Ask Witnet to retrieve token's metadata roots from the token base uri provider:
        {
            string[][] memory _args = new string[][](1);
            _args[0] = new string[](1);
            _args[0][0] = string(abi.encodePacked(
                bytes(baseURI()),
                "roots/",
                block.chainid.toString(),
                "/",
                _tokenId.toString()                
            ));
            __requests.tokenRoots = WitnetRequestTemplate(payable(address(witnetRequestTokenRoots.clone())));
            __requests.tokenRoots.initialize(abi.encode(WitnetRequestTemplate.InitData({
                args: _args,
                tallyHash: _tallyHash,
                slaHash: _slaHash,
                resultMaxSize: 0
            })));
            _usedFunds += __requests.imageDigest.post{value: msg.value - _usedFunds}();
        }

        // Transfer back unused funds, if any:
        if (_usedFunds < msg.value) {
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }

        emit Minting(_tokenId, baseURI(), _imageURI, _slaHash);
    }

    modifier tokenInStatus(uint256 _tokenId, WittyPixels.TokenStatus _status) {
        require(getTokenStatus(_tokenId) == _status, "WittyPixelsToken: bad mood");
        _;
    }

    function mint(
            uint256 _tokenId,
            WittyPixels.TokenEvent memory _theEvent,
            WittyPixels.TokenCanvas memory _theCanvas,
            WittyPixels.TokenStats memory _theStats
        )
        external
        onlyOwner
        nonReentrant
        tokenInStatus(_tokenId, WittyPixels.TokenStatus.Minting)
    {
        WittyPixels.TokenMetadata storage __metadata = __storage.items[_tokenId];
        WittyPixels.TokenWitnetRequests storage __requests = __storage.witnetRequests[_tokenId];
        
        bool _resultOk; bytes memory _resultBytes;        
        // Check the image URI actually exists, and store image digest hash, 
        // as provided by the Witnet oracle:
        {
            (_resultOk, _resultBytes) = __requests.imageDigest.read();
            require(_resultOk, "WittyPixelsToken: image digest failed");
            __metadata.block = block.number;
            __metadata.imageDigest = _resultBytes.toBytes32();
        }

        // Check the token data root reported by Witnet matches the rest of token's
        // metadata, including the image digest:
        {
            (_resultOk, _resultBytes) = __requests.tokenRoots.read();
            require(_resultOk, "WittyPixelsToken: token roots failed");
            WittyPixels.TokenRoots memory _roots = abi.decode(_resultBytes, (WittyPixels.TokenRoots));
            require(
                keccak256(abi.encode(
                    __metadata.imageDigest,
                    _theEvent,
                    _theCanvas,
                    _theStats,
                    _roots.names,
                    _roots.scores
                )) == _roots.data,
                "WittyPixelsToken: token roots mistmatch"
            );
            __metadata.theRoots = _roots;
        }
        
        // Check the event data:
        {
            require(
                bytes(_theEvent.name).length > 0
                    && bytes(_theEvent.venue).length > 0,
                "WittyPixelsToken: event empty strings"
            );
            require(
                _theEvent.startTs <= _theEvent.endTs,
                "WittyPixelsToken: event bad timestamps"
            );
            __metadata.theEvent = _theEvent;
        }
        
        // Set the token's canvas and game stats:
        {
            __metadata.theCanvas = _theCanvas;
            __metadata.theStats = _theStats;
        }

        // Mint the actual ERC-721 token:
        _safeMint(msg.sender, _tokenId);
    }

    /// @notice Sets collection's base URI.
    function setBaseURI(string calldata _uri)
        external 
        override
        onlyOwner
    {
        __storage.baseURI = WittyPixels.checkBaseURI(_uri);
    }

    /// @notice Vault logic contract to be used in next fractions.
    /// @dev Prototype ownership needs to have been previously transferred to this contract.
    function setTokenVaultPrototype(address _prototype)
        external
        override
        onlyOwner
    {
        require(
            _prototype.supportsInterface(type(ITokenVaultWitnet).interfaceId)
                && _prototype.supportsInterface(type(Clonable).interfaceId)
                && _prototype.supportsInterface(type(Ownable).interfaceId),
            "WittyPixelsToken: uncompliant prototype"
        );
        require(
            Ownable(_prototype).owner() == address(this), 
            "WittyPixelsToken: unowned protype"
        );
        __storage.tokenVaultPrototype = ITokenVaultWitnet(_prototype);
    }
}
