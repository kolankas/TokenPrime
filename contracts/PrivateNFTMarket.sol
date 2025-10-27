// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { FHE, euint64, externalEuint64 } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/// @title Private NFT Marketplace — Confidential Bids & Purchases
contract PrivateNFTMarket is ERC721, SepoliaConfig {
    address public owner;
    uint256 private _tokenIds;

    struct Listing {
        address seller;
        euint64 price; // encrypted price
        bool active;
    }

    struct Bid {
        address bidder;
        euint64 amount; // encrypted bid
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Bid[]) public bids;

    event NFTMinted(uint256 tokenId, address to);
    event Listed(uint256 tokenId);
    event BidPlaced(uint256 tokenId, address bidder);
    event SaleExecuted(uint256 tokenId, address buyer);

    constructor() ERC721("PrivateNFT", "pNFT") {
        owner = msg.sender;
    }

    function mint() external {
        _tokenIds++;
        _mint(msg.sender, _tokenIds);
        emit NFTMinted(_tokenIds, msg.sender);
    }

    function list(uint256 tokenId, externalEuint64 encryptedPrice, bytes calldata proof) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        euint64 price = FHE.fromExternal(encryptedPrice, proof);

        listings[tokenId] = Listing(msg.sender, price, true);

        FHE.allowThis(price);
        FHE.allow(price, msg.sender);

        emit Listed(tokenId);
    }

    function placeBid(uint256 tokenId, externalEuint64 encryptedBid, bytes calldata proof) external {
        require(listings[tokenId].active, "Not active");

        euint64 bidAmt = FHE.fromExternal(encryptedBid, proof);
        bids[tokenId].push(Bid(msg.sender, bidAmt));

        FHE.allowThis(bidAmt);
        FHE.allow(bidAmt, msg.sender);

        emit BidPlaced(tokenId, msg.sender);
    }

    function acceptBid(uint256 tokenId, uint256 bidIndex) external {
        Listing storage listing = listings[tokenId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "Not active");

        Bid storage chosen = bids[tokenId][bidIndex];

        // executed = (bid >= price) ? bid : 0
        euint64 executed = FHE.select(
            FHE.ge(chosen.amount, listing.price),
            chosen.amount,
            FHE.asEuint64(0)
        );

        // transfer NFT if successful
        _transfer(listing.seller, chosen.bidder, tokenId);
        listing.active = false;

        FHE.allowThis(executed);
        FHE.allow(executed, chosen.bidder);
        FHE.allow(executed, msg.sender);

        emit SaleExecuted(tokenId, chosen.bidder);
    }
}
