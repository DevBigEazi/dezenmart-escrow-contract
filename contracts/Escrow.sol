// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Escrow is ReentrancyGuard {
    enum Status {
        NONE,
        ACCEPTED,
        REJECTED,
        PENDING,
        DELIVERED,
        COMPLETED,
        DISPUTED,
        REFUNDED
    }

    enum ProductAvailable {
        UNDER_REVIEW,
        YES,
        NO
    }

    address public escrowAcc;
    uint256 public escrowFee;
    uint256 public escrowBal; // to keep track of funds sent to the account
    uint256 public escrowAvailBal; // this holds all the fees received for every transaction.

    uint256 public totalProductsUploaded = 0;
    uint256 public totalTradesCompleted = 0;
    uint256 public totalTradesDisputed = 0;
    uint256 public totalRejectedProduct = 0;
    uint256 public totalAcceptedProduct = 0;

    struct Products {
        uint256 productId;
        string description;
        uint256 price;
        uint256 createdAt;
        address owner;
        address buyer;
        Status status;
        bool sold;
    }

    mapping(uint256 => Products) private products; // will keep track of all the products uploaded
    mapping(address => Products[]) private productsOf; // holds the products of a specific user according to his address.
    mapping(address => mapping(uint256 => bool)) public requested; // keep track of every product a user has requested to buy whenever a product becomes available
    mapping(uint256 => address) public ownerOf; // keeps track of the owner or creator of each prouduct
    mapping(uint256 => ProductAvailable) public isProductAvailable; // keeps track of products that have not been assigned to another buyer.

    constructor() {
        escrowAcc = msg.sender;
        escrowFee = 5e17; // 0.5 dollars.
        escrowBal = 0;
        escrowAvailBal = 0;
    }

    event ProposeToListProductSuccessful(
        uint256 _productId,
        address indexed _executor,
        string _availability
    );
    event acceptProposedProductSuccessful(
        uint256 _productId,
        string _availability
    );
    event rejectProductSuccessful(uint256 _productId, string _availability);

    function ProposeToListProduct(
        string calldata _description
    ) external payable returns (bool) {
        require(msg.sender != address(0), "Address zero not allowed");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(msg.value > 0 ether, "Product price cannot be zero ethers");

        // listing the product
        uint256 productId = totalProductsUploaded++;

        Products storage product = products[productId];
        product.productId = productId;
        product.description = _description;
        product.price = msg.value;
        product.createdAt = block.timestamp;
        product.owner = msg.sender;

        // Assigning to owner and stating availability
        productsOf[msg.sender].push(product);
        ownerOf[productId] = msg.sender;
        isProductAvailable[productId] = ProductAvailable.UNDER_REVIEW;

        emit ProposeToListProductSuccessful(
            productId,
            msg.sender,
            "UNDER REVIEW"
        );

        return true;
    }

    function acceptProposedProduct(uint256 _productId) external returns (bool) {
        require(msg.sender == escrowAcc, "Unauthorized");
        require(msg.sender != address(0), "Address zero not allowed");

        // Check if the product exists by verifying its owner or other unique property
        require(
            products[_productId].owner != address(0),
            "Product does not exist"
        );

        require(
            products[_productId].status != Status.ACCEPTED &&
                products[_productId].status != Status.REJECTED,
            "Product already processed"
        );

        // Ensure the product is not already accepted
        require(
            isProductAvailable[_productId] != ProductAvailable.YES,
            "Product is already accepted"
        );

        products[_productId].status = Status.ACCEPTED;

        isProductAvailable[_productId] = ProductAvailable.YES;

        totalAcceptedProduct++;

        emit acceptProposedProductSuccessful(_productId, " YES: ACCEPTED");

        return true;
    }

    function rejectProposedProduct(uint256 _productId) external returns (bool) {
        require(msg.sender == escrowAcc, "Unauthorized");
        require(msg.sender != address(0), "Address zero not allowed");

        // Check if the product exists by verifying its owner or other unique property
        require(
            products[_productId].owner != address(0),
            "Product does not exist"
        );

        // Ensure the product has not been accepted or rejected already
        require(
            products[_productId].status != Status.ACCEPTED &&
                products[_productId].status != Status.REJECTED,
            "Product already processed"
        );

        // Ensure the product is not already rejected
        require(
            isProductAvailable[_productId] != ProductAvailable.NO,
            "Product already rejected"
        );

        products[_productId].status = Status.REJECTED;

        isProductAvailable[_productId] = ProductAvailable.NO;

        totalRejectedProduct++;

        emit rejectProductSuccessful(_productId, "NO: REJECTED");

        return true;
    }
}
