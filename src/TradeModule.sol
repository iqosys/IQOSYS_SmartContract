// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ITradeModule.sol";
import "./IAccessControl.sol";
import "./ITokenManager.sol";
import "./IOrderBookModule.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol"; 

/// @title Trade Module
/// @notice Executes and validates trades by matching orders from the order book

contract TradeModule is ITradeModule, ERC2771Context {
    IAccessControl public accessControl;
    ITokenManager public tokenManager;
    IOrderBookModule public orderBook;

    uint256 private nextExecutedTradeId;
    uint256 private nextValidateExecutedTradeId;
    
    mapping(uint256 => ExecutedTrade) public executedTrades;
    mapping(uint256 => ValidateExecutedTrade) public validateexecutedTrades;

    event TradeExecuted(
        uint256 indexed id,
        uint256 indexed sellOrderId,
        uint256 indexed buyOrderId,
        address seller,
        address buyer,
        uint256 amount,
        uint256 price,
        bool isIQS,
        uint256 timestamp
    );
    event ExecutedTradeValidated(
        uint256 indexed id,
        uint256 indexed sellOrderId,
        uint256 indexed buyOrderId,
        address seller,
        address buyer,
        uint256 amount,
        uint256 price,
        bool isIQS,
        uint256 timestamp
    );
    event ExecutedTradeRejected(
        uint256 indexed id,
        uint256 indexed sellOrderId,
        uint256 indexed buyOrderId,
        address seller,
        address buyer,
        bool isIQS,
        uint256 timestamp
    );


    modifier onlyValidSender() {
        address sender = _msgSender();
        require(accessControl.isWhiteListed(sender), "Sender not whitelisted");
        require(accessControl.isAuthorized(sender), "Sender not authorized");
        require(!accessControl.isFrozen(sender), "Sender is frozen");
        _;
    }


    constructor(
        address _accessControl, 
        address _tokenManager, 
        address _orderBook, 
        address forwarder
    ) ERC2771Context(forwarder) {
        accessControl = IAccessControl(_accessControl);
        tokenManager = ITokenManager(_tokenManager);
        orderBook = IOrderBookModule(_orderBook);
    }

    /// @inheritdoc ITradeModule
    function OrderSellFill(uint256 sellOrderId) external onlyValidSender {
        address sender = _msgSender(); 

        IOrderBookModule.SellOrder memory o = orderBook.sellOrdersf(sellOrderId);
        require(o.seller != address(0), "No such sell order");
        require(o.seller != sender, "Cannot buy your own order");


        executedTrades[nextExecutedTradeId] = ExecutedTrade({
            id:            nextExecutedTradeId,
            sellOrderId:   sellOrderId,
            buyOrderId:    0,
            seller:        o.seller,
            buyer:         sender, // 
            amount:        o.amount,
            price:         o.price,
            isIQS:         o.isIQS,
            timestamp:     block.timestamp
        });

        emit TradeExecuted(
            nextExecutedTradeId,
            sellOrderId,
            0,
            o.seller,
            sender,
            o.amount,
            o.price,
            o.isIQS,
            block.timestamp
        );
        nextExecutedTradeId++;

        orderBook.deleteSellOrder(sellOrderId);
    }


    /// @inheritdoc ITradeModule
    function OrderBuyFill(uint256 buyOrderId) external override onlyValidSender {
        address sender = _msgSender(); 

        IOrderBookModule.BuyOrder memory o = orderBook.buyOrdersf(buyOrderId);
        require(o.buyer != address(0), "No such buy order");
        require(o.buyer != sender, "Cannot sell your own order");

        if (o.isIQS) {
            require(tokenManager.balanceOfIQS(accessControl.owner()) >= o.amount, "Insufficient IQS balance in owner address");

            tokenManager.transferIQSfromAtoB(sender, accessControl.owner(), o.amount); 

        } else {
            require(tokenManager.balanceOfOST(accessControl.owner()) >= o.amount, "Insufficient OST balance in owner address");
            tokenManager.transferOSTfromAtoB(sender, accessControl.owner(), o.amount);
        }

        // Enregistrement du trade exécuté
        executedTrades[nextExecutedTradeId] = ExecutedTrade({
            id:            nextExecutedTradeId,
            sellOrderId:   0,
            buyOrderId:    buyOrderId,
            seller:        sender, 
            buyer:         o.buyer,
            amount:        o.amount,
            price:         o.price,
            isIQS:         o.isIQS,
            timestamp:     block.timestamp
        });

        emit TradeExecuted(
            nextExecutedTradeId,
            0,
            buyOrderId,
            sender,
            o.buyer,
            o.amount,
            o.price,
            o.isIQS,
            block.timestamp
        );
        nextExecutedTradeId++;

        orderBook.deleteBuyOrder(buyOrderId);
    }

    /// @inheritdoc ITradeModule
    function validateExecutedTrade(uint256 executedTradeId) external override {

        require(_msgSender() == accessControl.owner(), "Only owner");
        
        ExecutedTrade storage et = executedTrades[executedTradeId];
        require(et.seller != address(0), "No such executed trade");


        if (et.isIQS) {
            require(tokenManager.balanceOfIQS(accessControl.owner()) >= et.amount, "Insufficient IQS balance in owner address");
            tokenManager.transferIQSfromAtoB(accessControl.owner(), et.buyer, et.amount);
            tokenManager._addIQSHolder(et.buyer);
        } else {
            require(tokenManager.balanceOfOST(accessControl.owner()) >= et.amount, "Insufficient OST balance in owner address");
            tokenManager.transferOSTfromAtoB(accessControl.owner(), et.buyer, et.amount);
            tokenManager._addOSTHolder(et.buyer);
        }

        // Archive le trade validé
        validateexecutedTrades[nextValidateExecutedTradeId] = ValidateExecutedTrade({
            id:            nextValidateExecutedTradeId,
            sellOrderId:   et.sellOrderId,
            buyOrderId:    et.buyOrderId,
            seller:        et.seller,
            buyer:         et.buyer,
            amount:        et.amount,
            price:         et.price,
            isIQS:         et.isIQS,
            timestamp:     et.timestamp
        });
        emit ExecutedTradeValidated(
            nextValidateExecutedTradeId,
            et.sellOrderId,
            et.buyOrderId,
            et.seller,
            et.buyer,
            et.amount,
            et.price,
            et.isIQS,
            et.timestamp
        );
        nextValidateExecutedTradeId++;

        // Nettoyage de l’entrée temporaire
        delete executedTrades[executedTradeId];
    }

    /// @inheritdoc ITradeModule
    function rejectExecutedTrade(uint256 executedTradeId) external override {

        require(_msgSender() == accessControl.owner(), "Only owner");
        
        ExecutedTrade storage et = executedTrades[executedTradeId];
        require(et.seller != address(0), "No such executed trade");

        // Restitution des tokens depuis l’escrow 
        if (et.isIQS) {
            address ownerAddress = accessControl.owner();
            require(tokenManager.balanceOfIQS(ownerAddress) >= et.amount, "Insufficient IQS balance in owner address");
            tokenManager.transferIQSfromAtoB(accessControl.owner(), et.seller, et.amount);
        } else {
            address ownerAddress = accessControl.owner();
            require(tokenManager.balanceOfOST(ownerAddress) >= et.amount, "Insufficient OST balance in owner address");
            tokenManager.transferOSTfromAtoB(accessControl.owner(), et.seller, et.amount);
        }

        emit ExecutedTradeRejected(
            executedTradeId,
            et.sellOrderId,
            et.buyOrderId,
            et.seller,
            et.buyer,
            et.isIQS,
            et.timestamp
        );

        delete executedTrades[executedTradeId];
    }

    /// @inheritdoc ITradeModule
    function executedTradesf(uint256 id) external view override returns (ExecutedTrade memory) {
        return executedTrades[id];
    }

    /// @inheritdoc ITradeModule
    function validateexecutedTradesf(uint256 id) external view override returns (ExecutedTrade memory) {
        ValidateExecutedTrade storage vTrade = validateexecutedTrades[id];
        return ExecutedTrade({
            id: vTrade.id,
            sellOrderId: vTrade.sellOrderId,
            buyOrderId: vTrade.buyOrderId,
            seller: vTrade.seller,
            buyer: vTrade.buyer,
            amount: vTrade.amount,
            price: vTrade.price,
            isIQS: vTrade.isIQS,
            timestamp: vTrade.timestamp
        });
    }

    /// @inheritdoc ITradeModule
    function nextExecutedTradeIdf() external view override returns (uint256) {
        return nextExecutedTradeId;
    }

    /// @inheritdoc ITradeModule
    function nextValidateExecutedTradeIdf() external view returns (uint256) {
        return nextValidateExecutedTradeId;
    }

    /// @inheritdoc ITradeModule
    function calculateTotalCost(uint256 executedTradeId) external view returns (uint256 total) {
        ExecutedTrade storage et = executedTrades[executedTradeId];
        require(et.seller != address(0), "No such executed trade");

        uint256 base = et.amount * et.price;
        uint256 pct  = (base * tokenManager.transactionFeeRatef()) / 100;   // calcule d’abord base*rate, puis divise
        return base + pct + tokenManager.transactionFeef();
    }

    /// @inheritdoc ITradeModule
    function getUserValidatedTradesOrderBook(address user) external view
        returns (
            uint256[] memory ids,
            uint256[] memory sellOrderIds,
            uint256[] memory buyOrderIds,
            address[] memory sellers,
            address[] memory buyers,
            uint256[] memory amounts,
            uint256[] memory prices,
            bool[]    memory isIQSFlags,
            uint256[] memory timestamps
        )
    {
        uint256 total = nextValidateExecutedTradeId;
        uint256 count = 0;
        for (uint256 i = 0; i < total; i++) {
            ValidateExecutedTrade storage t = validateexecutedTrades[i];
            if (t.seller == user || t.buyer == user) {
                count++;
            }
        }
        ids           = new uint256[](count);
        sellOrderIds  = new uint256[](count);
        buyOrderIds   = new uint256[](count);
        sellers       = new address[](count);
        buyers        = new address[](count);
        amounts       = new uint256[](count);
        prices        = new uint256[](count);
        isIQSFlags    = new bool[](count);
        timestamps    = new uint256[](count);

        uint256 idx = 0;
        for (uint256 i = 0; i < total; i++) {
            ValidateExecutedTrade storage t = validateexecutedTrades[i];
            if (t.seller == user || t.buyer == user) {
                ids[idx]           = t.id;
                sellOrderIds[idx]  = t.sellOrderId;
                buyOrderIds[idx]   = t.buyOrderId;
                sellers[idx]       = t.seller;
                buyers[idx]        = t.buyer;
                amounts[idx]       = t.amount;
                prices[idx]        = t.price;
                isIQSFlags[idx]    = t.isIQS;
                timestamps[idx]    = t.timestamp;
                idx++;
            }
        }
    }

    /// @inheritdoc ITradeModule
    function getUserIQSTradesOrderBook(address user) external view
        returns (
            uint256[] memory ids,
            uint256[] memory sellOrderIds,
            uint256[] memory buyOrderIds,
            address[] memory sellers,
            address[] memory buyers,
            uint256[] memory amounts,
            uint256[] memory prices,
            uint256[] memory timestamps
        )
    {
        uint256 total = nextValidateExecutedTradeId;
        uint256 count = 0;

        for (uint256 i = 0; i < total; i++) {
            ValidateExecutedTrade storage t = validateexecutedTrades[i];
            if (t.isIQS && (t.seller == user || t.buyer == user)) {
                count++;
            }
        }


        ids           = new uint256[](count);
        sellOrderIds  = new uint256[](count);
        buyOrderIds   = new uint256[](count);
        sellers       = new address[](count);
        buyers        = new address[](count);
        amounts       = new uint256[](count);
        prices        = new uint256[](count);
        timestamps    = new uint256[](count);


        uint256 idx = 0;
        for (uint256 i = 0; i < total; i++) {
            ValidateExecutedTrade storage t = validateexecutedTrades[i];
            if (t.isIQS && (t.seller == user || t.buyer == user)) {
                ids[idx]          = t.id;
                sellOrderIds[idx] = t.sellOrderId;
                buyOrderIds[idx]  = t.buyOrderId;
                sellers[idx]      = t.seller;
                buyers[idx]       = t.buyer;
                amounts[idx]      = t.amount;
                prices[idx]       = t.price;
                timestamps[idx]   = t.timestamp;
                idx++;
            }
        }
    }

    /// @inheritdoc ITradeModule
    function getAllValidatedTrades() external view
        returns (
            uint256[] memory ids,
            uint256[] memory sellOrderIds,
            uint256[] memory buyOrderIds,
            address[] memory sellers,
            address[] memory buyers,
            uint256[] memory amounts,
            uint256[] memory prices,
            bool[]    memory isIQSFlags,
            uint256[] memory timestamps
        )
    {
        uint256 total = nextValidateExecutedTradeId;
        ids           = new uint256[](total);
        sellOrderIds  = new uint256[](total);
        buyOrderIds   = new uint256[](total);
        sellers       = new address[](total);
        buyers        = new address[](total);
        amounts       = new uint256[](total);
        prices        = new uint256[](total);
        isIQSFlags    = new bool[](total);
        timestamps    = new uint256[](total);

        for (uint256 i = 0; i < total; i++) {
            ValidateExecutedTrade storage t = validateexecutedTrades[i];
            ids[i]           = t.id;
            sellOrderIds[i]  = t.sellOrderId;
            buyOrderIds[i]   = t.buyOrderId;
            sellers[i]       = t.seller;
            buyers[i]        = t.buyer;
            amounts[i]       = t.amount;
            prices[i]        = t.price;
            isIQSFlags[i]    = t.isIQS;
            timestamps[i]    = t.timestamp;
        }
    }

    /// @inheritdoc ITradeModule
    function getTransactionHistoryLengthOrderBook() external view returns (uint256) {
        return nextValidateExecutedTradeId - 1 ; 
    }

   

    function _msgSender() internal view override(ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override(ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength() internal view override(ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}