pragma solidity 0.8.7;

/*

  _____ _            _____     _      ____      _          ____ _       _     
 |_   _| |__   ___  |  ___|_ _| |_   / ___|__ _| |_ ___   / ___| |_   _| |__  
   | | | '_ \ / _ \ | |_ / _` | __| | |   / _` | __/ __| | |   | | | | | '_ \ 
   | | | | | |  __/ |  _| (_| | |_  | |__| (_| | |_\__ \ | |___| | |_| | |_) |
   |_| |_| |_|\___| |_|  \__,_|\__|  \____\__,_|\__|___/  \____|_|\__,_|_.__/ 
                                                                              

*/

// Errors
error TheFatTigers__InvalidContractInit();
error TheFatTigers__InvalidRoyaltyBips(uint96 _royaltyBips);
error TheFatTigers__InvalidMintAmount();
error TheFatTigers__MaxSupplyExceeded();
error TheFatTigers__ContractPaused();
error TheFatTigers__MintComplete();
error TheFatTigers__InvalidTSOConfig(address _tsoAddress);
error TheFatTigers__IncorrectFunds(uint256 _sentAmount);
error TheFatTigers__WhitelistInactive();
error TheFatTigers__ExceedsWhitelistAllowance();
error TheFatTigers__InvalidMaxSupply(
  uint256 _currentSupply,
  uint256 _maxSupply,
  uint256 _maxPossible
);

contract TheFatTigers is ERC721Royalty, ERC721Enumerable, Ownable, ReentrancyGuard {
  using Strings for uint256;

  /* State Variables */

  // Constants
  uint256 public constant PRICEUSD = 150;
  uint256 public constant WHITELIST_DISCOUNT_BIPS = 1000; // 10 percent
  uint256 public constant CURRENCY_SYMBOL_IDX = 0; // index of the currency symbol assuming ["SGB", "FLR"] ordering.

  // Private
  uint256[6000] private nftIds;

  // Public
  IFtso public sparkTso;
  mapping(address => uint256) public whitelist;

  string public uriPrefix = "";
  string public uriSuffix = ".json";
  string public hiddenMetadataUri;

  uint256 public maxSupply = 6000;
  uint256 public maxMintAmountPerTx = 20;
  uint256 public priceSpark = 7500 ether;
  uint256 public precision = 6;

  bool public useManualPrice = true;
  bool public paused = true;
  bool public isWhitelistActive = false;
  bool public revealed = false;

  /* Events */
  event Revealed(bool indexed _state);
  event Paused(bool indexed _state);
  event WhitelistOpened(bool indexed _state);

  modifier mintCompliance(uint256 _mintAmount) {
    if (_mintAmount == 0 || (_mintAmount > maxMintAmountPerTx)) {
      revert TheFatTigers__InvalidMintAmount();
    }
    if ((totalSupply() + _mintAmount) > maxSupply) {
      revert TheFatTigers__MaxSupplyExceeded();
    }
    _;
  }

  modifier mintPriceCompliance(uint256 _mintAmount, bool _asWhitelist) {
    uint256 basePrice = price();
    uint256 newPrice;
    if (_asWhitelist) {
      newPrice = whitelistPrice();
    } else {
      newPrice = basePrice;
    }
    if (msg.value != (newPrice * _mintAmount)) {
      revert TheFatTigers__IncorrectFunds(msg.value);
    }
    _;
  }

  /**
    @param _sparkTsoAddress Address of the relevant Spark Flare/Songbird Time Series Oracle.
    @param _royaltyReceiver Address where royalties should be sent to.
    @param _royaltyBips The royalty percentage in bips (100% = 10000).
   */
  constructor(
    address _sparkTsoAddress,
    address _royaltyReceiver,
    uint96 _royaltyBips
  ) ERC721("The Fat Tigers", "FATTIGR") {
    // Check nftIds and maxSupply initialisation matches
    if (nftIds.length != maxSupply) {
      revert TheFatTigers__InvalidContractInit();
    }
    // Set up TSO with basic checks
    setSparkTso(_sparkTsoAddress);
    // Set up Royalty info and other metadata
    setRoyaltyInfo(_royaltyReceiver, _royaltyBips);
    setHiddenMetadataUri("ipfs://QmSGZ9wA7DYLcHxZCVsSCiEKQte38b5FJwd2H77sfpHcHB/hidden.json");
  }

  // public
  function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
    require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");

    if (revealed == false) {
      return hiddenMetadataUri;
    }

    string memory currentBaseURI = _baseURI();
    return
      bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
        : "";
  }

  /**
   * @dev Gets the manually set priceSpark if useManualPrice is true or sparkTso address is null. Otherwise uses TSO conversion.
   */
  function price() public view returns (uint256 _price) {
    if (useManualPrice || address(sparkTso) == address(0x0)) {
      _price = priceSpark;
    } else {
      // The below reverts if using a bad Spark TSO address (i.e. if address is not a TSO)
      (
        uint256 usdPerSpark, /* timestamp */

      ) = sparkTso.getCurrentPrice();
      uint256 numDecimals = sparkTso.ASSET_PRICE_USD_DECIMALS();
      uint256 usdPow = PRICEUSD * 10**(numDecimals + precision);
      uint256 numSpark = (usdPow / usdPerSpark);
      _price = numSpark * 10**(18 - precision);
    }
  }

  function whitelistPrice() public view returns (uint256 _whitelistPrice) {
    uint256 basePrice = price();
    uint256 numerator = (basePrice * WHITELIST_DISCOUNT_BIPS);
    uint256 denomBips = 10000;
    return basePrice - (numerator / denomBips);
  }

  // external
  function mint(uint256 _mintAmount)
    external
    payable
    mintCompliance(_mintAmount)
    mintPriceCompliance(_mintAmount, false)
  {
    if (paused) {
      revert TheFatTigers__ContractPaused();
    }
    _mintLoop(msg.sender, _mintAmount);
  }

  function walletOfOwner(address _owner) external view returns (uint256[] memory) {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);

    for (uint256 i = 0; i < ownerTokenCount; i++) {
      uint256 tokenIdAtIndex = tokenOfOwnerByIndex(_owner, i);
      ownedTokenIds[i] = tokenIdAtIndex;
    }

    return ownedTokenIds;
  }

  // WL - external
  function mintWhitelist(uint256 _mintAmount)
    external
    payable
    mintCompliance(_mintAmount)
    mintPriceCompliance(_mintAmount, true)
  {
    if (!isWhitelistActive) {
      revert TheFatTigers__WhitelistInactive();
    }
    if (_mintAmount > whitelist[msg.sender]) {
      revert TheFatTigers__ExceedsWhitelistAllowance();
    }
    whitelist[msg.sender] -= _mintAmount;
    _mintLoop(msg.sender, _mintAmount);
  }

  // Giveaways - external
  function mintForAddress(uint256 _mintAmount, address _receiver)
    external
    mintCompliance(_mintAmount)
    onlyOwner
  {
    _mintLoop(_receiver, _mintAmount);
  }

  // onlyOwner - public
  function setSparkTso(address _sparkTsoAddress) public onlyOwner {
    IFtso tsoContract = IFtso(_sparkTsoAddress);
    // It is ok to set the TSO to null. This means it will fail TSO checks
    // if useManualPrice is false.
    if (_sparkTsoAddress != address(0x0) && !_checkTsoConfig(tsoContract)) {
      revert TheFatTigers__InvalidTSOConfig(_sparkTsoAddress);
    }
    sparkTso = tsoContract;
  }

  function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
    hiddenMetadataUri = _hiddenMetadataUri;
  }

  function setRoyaltyInfo(address _royaltyReceiver, uint96 _royaltyBips) public onlyOwner {
    if (_royaltyBips > 10000) {
      revert TheFatTigers__InvalidRoyaltyBips(_royaltyBips);
    }
    super._setDefaultRoyalty(_royaltyReceiver, _royaltyBips);
  }

  // onlyOwner - external
  function setMaxSupply(uint256 _maxSupply) external onlyOwner {
    uint256 currentSupply = totalSupply();
    // Do not allow maxSupply change if:
    // 1. Mint has started, meaning currentSupply is not zero.
    // 2. Mint has not started, but we are extending beyond nftIds init value, as this will break
    // the mint.
    if (_maxSupply > nftIds.length || currentSupply > 0) {
      revert TheFatTigers__InvalidMaxSupply(currentSupply, _maxSupply, nftIds.length);
    }
    maxSupply = _maxSupply;
  }

  function setWhitelistActive(bool _isWhitelistActive) external onlyOwner {
    isWhitelistActive = _isWhitelistActive;
    emit WhitelistOpened(_isWhitelistActive);
  }

  function setWhitelist(address[] calldata _addresses, uint256 _numAllowedToMint)
    external
    onlyOwner
  {
    for (uint256 i = 0; i < _addresses.length; i++) {
      whitelist[_addresses[i]] = _numAllowedToMint;
    }
  }

  function setRevealed(bool _state) external onlyOwner {
    revealed = _state;
    emit Revealed(_state);
  }

  function setUseManualPrice(bool _useManualPrice) external onlyOwner {
    useManualPrice = _useManualPrice;
  }

  function setPriceSpark(uint256 _priceSpark) external onlyOwner {
    priceSpark = _priceSpark;
  }

  function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) external onlyOwner {
    maxMintAmountPerTx = _maxMintAmountPerTx;
  }

  function setUriPrefix(string memory _uriPrefix) external onlyOwner {
    uriPrefix = _uriPrefix;
  }

  function setUriSuffix(string memory _uriSuffix) external onlyOwner {
    uriSuffix = _uriSuffix;
  }

  function setPaused(bool _state) external onlyOwner {
    paused = _state;
    emit Paused(_state);
  }

  function setPrecision(uint256 _precision) external onlyOwner {
    precision = _precision;
  }

  function withdraw(bool asTest) external onlyOwner nonReentrant {
    require(
      !asTest || (asTest && address(this).balance >= 1 ether),
      "Insufficient funds to run test!"
    );
    require(address(this).balance > 0, "No funds to withdraw!");
    // Transfer funds to owner
    // =============================================================================
    if (asTest) {
      (bool sent, ) = payable(owner()).call{value: 1 ether}("");
      require(sent, "Couldn't send test amount");
    } else {
      (bool sent, ) = payable(owner()).call{value: address(this).balance}("");
      require(sent, "Couldn't send balance");
    }
    // =============================================================================
  }

  // Internal
  function _mintLoop(address _receiver, uint256 _mintAmount) internal {
    for (uint256 i = 0; i < _mintAmount; i++) {
      uint256 _random = uint256(
        keccak256(
          abi.encodePacked(totalSupply(), msg.sender, block.timestamp, blockhash(block.number - 1))
        )
      );
      uint256 _randomId = _pickRandomUniqueId(_random);
      _safeMint(_receiver, _randomId);
    }
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return uriPrefix;
  }

  /**
   * @dev Test TSO has required functionality.
   * @param _tso TSO expected to conform with IFtso interface.
   */
  function _checkTsoConfig(IFtso _tso) internal view returns (bool _state) {
    // This is a hard-coded order, matching constructor assumptions
    string memory expectedSymbol = ["SGB", "FLR"][CURRENCY_SYMBOL_IDX];
    string memory foundSymbol = _tso.symbol();
    bool isCorrectSymbol = (keccak256(bytes(foundSymbol)) == keccak256(bytes(expectedSymbol)));
    bool isActive = _tso.active();
    (
      uint256 usdPerSpark, /* timestamp */

    ) = _tso.getCurrentPrice();
    // This is just a check that we can return this value without reverting
    _tso.ASSET_PRICE_USD_DECIMALS();
    _state = isCorrectSymbol && isActive && usdPerSpark > 0;
  }

  // Private
  function _pickRandomUniqueId(uint256 random) private returns (uint256) {
    // len uses maxSupply as we have the option to make maxSupply lower than
    // initial nftIds.length BEFORE mint starts. setMaxSupply checks that
    // maxSupply is never changed after mint starts (i.e. when totalSupply() > 0)
    uint256 len = maxSupply - (totalSupply());
    if (len <= 0) {
      revert TheFatTigers__MintComplete();
    }
    uint256 randomIndex = random % len;
    uint256 id = nftIds[randomIndex] != 0 ? nftIds[randomIndex] : randomIndex;
    id++; // 1 indexed tokenId
    nftIds[randomIndex] = uint256(nftIds[len - 1] == 0 ? len - 1 : nftIds[len - 1]);
    nftIds[len - 1] = 0;
    return id;
  }

  // Required overrides
  /**
   * @dev See {ERC721Enumerable-supportsInterface}, {ERC721Royalty-supportsInterface} and {ERC2981-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721Enumerable, ERC721Royalty)
    returns (bool)
  {
    // Each appends their own interface check so we need to
    // check for both.
    return
      ERC721Royalty.supportsInterface(interfaceId) ||
      ERC721Enumerable.supportsInterface(interfaceId);
  }

  /**
   * @dev See {ERC721-_burn} and {ERC721Royalty-_burn}.
   */
  function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721Royalty) {
    // Calls ERC721 _burn and then does required token royalty cleanup
    ERC721Royalty._burn(tokenId);
  }

  /**
   * @dev See {ERC721-_beforeTokenTransfer} and {ERC721Enumerable-_beforeTokenTransfer}.
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    // Calls ERC721-_beforeTokenTransfer and then does required index cleanup
    ERC721Enumerable._beforeTokenTransfer(from, to, tokenId);
  }
}