// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SimpleEnglishAuction is ReentrancyGuard {
    // AU-7: Custom errors
    error AuctionAlreadyEnded();
    error AuctionNotEnded();
    error AuctionNotCancelled();
    error BidTooLow();
    error NoBidsPlaced();
    error CannotCancelWithBids();
    error NotSeller();
    error NoRefundAvailable();

    // AU-2: Auction states
    enum AuctionState { STARTED, ENDED, CANCELLED }

    // AU-1: Auction parameters
    IERC721 public immutable nftContract; // NFT contract address
    uint256 public immutable tokenId; // NFT token ID
    uint256 public immutable startPrice; // Starting price in wei
    uint256 public immutable endTime; // Auction end timestamp
    address public immutable seller; // Seller address

    // Auction state variables
    AuctionState public state; // Current state (AU-2)
    address public highestBidder; // Current highest bidder
    uint256 public highestBid; // Current highest bid
    mapping(address => uint256) public pendingRefunds; // AU-4: Refunds for outbid bidders

    // Event for auction end (AU-5)
    event AuctionEnded(address indexed winner, uint256 price);

    // Constructor (AU-1)
    constructor(
        address _nftContract,
        uint256 _tokenId,
        uint256 _startPrice,
        uint256 _biddingPeriod
    ) {
        require(_nftContract != address(0), "Invalid NFT contract address");
        require(_startPrice > 0, "Start price must be greater than 0");
        require(_biddingPeriod > 0, "Bidding period must be greater than 0");

        nftContract = IERC721(_nftContract);
        tokenId = _tokenId;
        startPrice = _startPrice;
        endTime = block.timestamp + _biddingPeriod;
        seller = msg.sender;
        state = AuctionState.STARTED; // AU-3: Auction starts immediately
    }

    // AU-3: Place a bid
    function bid() external payable nonReentrant {
        if (state != AuctionState.STARTED) revert AuctionAlreadyEnded();
        if (block.timestamp >= endTime) revert AuctionAlreadyEnded();

        // Calculate minimum required bid (10% higher than current highest or start price)
        uint256 minBid = highestBid == 0 ? startPrice : (highestBid * 110) / 100;
        if (msg.value < minBid) revert BidTooLow();

        // Store previous highest bidder's amount for refund (AU-4)
        if (highestBidder != address(0)) {
            pendingRefunds[highestBidder] += highestBid;
        }

        // Update highest bid and bidder
        highestBid = msg.value;
        highestBidder = msg.sender;
    }

    // AU-5: End the auction
    function end() external nonReentrant {
        if (state != AuctionState.STARTED) revert AuctionAlreadyEnded();
        if (block.timestamp < endTime) revert AuctionNotEnded();

        state = AuctionState.ENDED;

        // Transfer NFT to winner if there is a bid
        if (highestBidder != address(0)) {
            nftContract.safeTransferFrom(address(this), highestBidder, tokenId);
            // Transfer highest bid to seller (AU-5)
            (bool success, ) = payable(seller).call{value: highestBid}("");
            require(success, "Transfer to seller failed");
            emit AuctionEnded(highestBidder, highestBid);
        } else {
            // If no bids, return NFT to seller
            nftContract.safeTransferFrom(address(this), seller, tokenId);
            emit AuctionEnded(address(0), 0);
        }
    }

    // AU-6: Seller can cancel auction if no bids
    function cancel() external nonReentrant {
        if (msg.sender != seller) revert NotSeller();
        if (state != AuctionState.STARTED) revert AuctionAlreadyEnded();
        if (highestBidder != address(0)) revert CannotCancelWithBids();

        state = AuctionState.CANCELLED;
        // Return NFT to seller
        nftContract.safeTransferFrom(address(this), seller, tokenId);
    }

    // AU-4: Claim refund for outbid or cancelled auction
    function claimRefund() external nonReentrant {
        if (state == AuctionState.STARTED) revert AuctionNotEnded();
        uint256 refundAmount = pendingRefunds[msg.sender];
        if (refundAmount == 0) revert NoRefundAvailable();

        pendingRefunds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund failed");
    }
}