// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "erc721a/contracts/ERC721A.sol";

error MsgValueNotCorrect();
error MintingStatusNotValid();
error MaxSupplyExceeded();
error ArraysWithDifferentLength();
error MintLimitForSaleExceeded();
error NotWhitelistedForPresale();

contract FatKittens is ERC721A, Ownable {
  using Strings for uint256;
  
  enum MintingStatus { 
    Paused,
    Presale,
    Sale
  }

  // Max number of NFTs
  uint16 public constant MAX_SUPPLY = 10000;

  // First tokenId from which mint will start
  uint8 public constant START_TOKEN_ID = 1;

  // Max mint tokens in public sale
  uint256 public constant MAX_TOKENS_FOR_SALE = 4000;

  // Mint cost in presale
  uint256 public presaleCost = 0.001 ether;

  // Mint cost in public sale
  uint256 public cost = 0.002 ether;

  // Minting status: 0 - paused, 1 - presale, 2 - sale
  MintingStatus public _saleFlag = MintingStatus.Paused;

  // Mint Counter
  uint256 public mintCounter = 0;

  // Base extension
  string public baseExtension = ".json";

  // IPFS Metadata URI
  string private _baseUri;

  // Addresses whitelisted for presale
  mapping(address => bool) private _presaleWhitelistAddresses;

  constructor(
      string memory name,
      string memory symbol,
      string memory base,
      address[] memory presaleWhitelistAddresses
  ) ERC721A(name, symbol) {
      _baseUri = base;

      for (uint i = 0; i < presaleWhitelistAddresses.length; i++) {
        _presaleWhitelistAddresses[presaleWhitelistAddresses[i]] = true;
      }
  }

  function _startTokenId() internal pure override returns (uint256) {
      return START_TOKEN_ID;
  }

  function _baseURI() internal view override returns (string memory) {
      return _baseUri;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

    string memory baseURI = _baseURI();
    return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), baseExtension)) : "";
  }

  function setPresaleCost(uint256 newPresaleCost) external onlyOwner {
    presaleCost = newPresaleCost;
  }

  function setCost(uint256 newCost) external onlyOwner {
    cost = newCost;
  }

  function setBaseUri(string memory newBase) external onlyOwner {
    _baseUri = newBase;
  }

  function setMintingStatus(uint8 saleFlag) external onlyOwner {
    _saleFlag = MintingStatus(saleFlag);
  }

  function getSum(uint256[] calldata numberOfTokensPerAddress) private pure returns(uint256) {
    uint i;
    uint sum = 0;
      
    for(i = 0; i < numberOfTokensPerAddress.length; i++)
      sum = sum + numberOfTokensPerAddress[i];

    return sum;
  }

  function airdrop(
    address[] calldata addresses, 
    uint256[] calldata numberOfTokensPerAddress
  ) external onlyOwner {
    if (addresses.length != numberOfTokensPerAddress.length) revert ArraysWithDifferentLength();
    if (totalSupply() + getSum(numberOfTokensPerAddress) > MAX_SUPPLY) revert MaxSupplyExceeded();

    uint i;
    for(i = 0; i < addresses.length; i++) {
      _safeMint(addresses[i], numberOfTokensPerAddress[i]);
    }
  }

  function mint(uint256 quantity) external payable {
    if (_saleFlag == MintingStatus.Paused) revert MintingStatusNotValid();

    uint256 expectedValue = cost * quantity;
    if (_saleFlag == MintingStatus.Presale) {
      if (!_presaleWhitelistAddresses[msg.sender]) revert NotWhitelistedForPresale();
      expectedValue = presaleCost * quantity;
    } 

    if (msg.value != expectedValue) revert MsgValueNotCorrect();
    if (mintCounter + quantity > MAX_TOKENS_FOR_SALE) revert MintLimitForSaleExceeded();
    if (totalSupply() + quantity > MAX_SUPPLY) revert MaxSupplyExceeded();

    mintCounter += quantity;
    _safeMint(_msgSender(), quantity);
  }

  function withdraw() external onlyOwner {
    (bool success, ) = msg.sender.call{value: address(this).balance}("");
    require(success, "Failed to withdraw funds!");
  }
}

