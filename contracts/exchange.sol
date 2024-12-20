// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "hardhat/console.sol";

contract TokenExchange is Ownable {
    string public exchange_name = "fzswap";

    // TODO: paste token contract address here
    // e.g. tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3
    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // TODO: paste token contract address here
    Token public token = Token(tokenAddr);

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    // Fee Pools
    uint private token_fee_reserves = 0;
    uint private eth_fee_reserves = 0;

    // Liquidity pool shares
    mapping(address => uint) private lps;

    // For Extra Credit only: to loop through the keys of the lps mapping
    address[] private lp_providers;

    // Total Pool Shares
    uint private total_shares = 0;

    // liquidity rewards
    uint private swap_fee_numerator = 3;
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    uint private multiplier = 10 ** 5;

    constructor() {}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens) external payable onlyOwner {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require(token_reserves == 0, "Token reserves was not 0");
        require(eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require(msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(
            amountTokens <= tokenSupply,
            "Not have enough tokens to create the pool"
        );
        require(amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;

        // Pool shares set to a large value to minimize round-off errors
        total_shares = 10 ** 5;
        // Pool creator has some low amount of shares to allow autograder to run
        lps[msg.sender] = 100;
    }

    // For use for ExtraCredit ONLY
    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(
            index < lp_providers.length,
            "specified index is larger than the number of lps"
        );
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // Function getReserves
    function getReserves() public view returns (uint, uint) {
        return (eth_reserves, token_reserves);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    /* ========================= Liquidity Provider Functions =========================  */

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(
        uint min_exchange_rate,
        uint max_exchange_rate
    ) external payable {
        /******* TODO: Implement this function *******/
        require(msg.value > 0, "Need ETH to add");

        uint amountETH = msg.value;
        uint amountTokens = (amountETH * token_reserves) / eth_reserves;

        require(
            amountTokens <= token.balanceOf(msg.sender),
            "You don't have enough token"
        );

        // exchange_rate = WEI / Token
        // => min * Token <= WEI <= max * Token;
        min_exchange_rate *= (10 ** 18);
        max_exchange_rate *= (10 ** 18);
        require(
            min_exchange_rate * amountTokens <= amountETH * multiplier &&
                amountETH * multiplier <= max_exchange_rate * amountTokens,
            "Out range of rate"
        );

        uint newSharesValue = (total_shares * amountETH) / eth_reserves;
        total_shares += newSharesValue;

        bool existStatus = false;

        for (uint index = 0; index < lp_providers.length; ++index) {
            if (lp_providers[index] == msg.sender) {
                lps[msg.sender] += newSharesValue;
                existStatus = true;
                break;
            }
        }

        eth_reserves += amountETH;
        token_reserves += amountTokens;
        //token.transfer(msg.sender, amountTokens);
        token.transferFrom(msg.sender, address(this), amountTokens);

        k = token_reserves * eth_reserves;

        if (!existStatus) {
            lps[msg.sender] = newSharesValue;
            lp_providers.push(msg.sender);
        }
    }

    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(
        uint amountETH,
        uint min_exchange_rate,
        uint max_exchange_rate
    ) public payable {
        /******* TODO: Implement this function *******/
        require(amountETH > 0, "Amount must be a positive.");
        uint amountTokens = (amountETH * token_reserves) / eth_reserves;

        require(
            amountETH < eth_reserves && amountTokens < token_reserves,
            "Cannot remove these amount."
        );

        // exchange_rate = WEI / Token
        // => min * Token <= WEI <= max * Token;
        min_exchange_rate *= (10 ** 18);
        max_exchange_rate *= (10 ** 18);
        require(
            min_exchange_rate * amountTokens <= amountETH * multiplier &&
                amountETH * multiplier <= max_exchange_rate * amountTokens,
            "Out range of rate"
        );

        uint sharesRemoved = (total_shares * amountETH) / eth_reserves;
        total_shares -= sharesRemoved;
        lps[msg.sender] -= sharesRemoved;

        eth_reserves -= amountETH;
        token_reserves -= amountTokens;

        payable(msg.sender).transfer(amountETH);
        token.transfer(msg.sender, amountTokens);
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(
        uint min_exchange_rate,
        uint max_exchange_rate
    ) external payable {
        /******* TODO: Implement this function *******/
        require(
            lps[msg.sender] > 0,
            "This liquidity provider is not having any ETH and tokens in pool."
        );

        uint amountETH = (eth_reserves * lps[msg.sender]) / total_shares;
        removeLiquidity(amountETH, min_exchange_rate, max_exchange_rate);

        lps[msg.sender] = 0;
        for (uint index = 0; index < lp_providers.length; ++index) {
            if (lp_providers[index] == msg.sender) {
                removeLP(index);
            }
        }
    }
    /***  Define additional functions for liquidity fees here as needed ***/

    /* ========================= Swap Functions =========================  */

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(
        uint amountTokens,
        uint max_exchange_rate
    ) external payable {
        /******* TODO: Implement this function *******/
        require(amountTokens > 0, "amount must be a possitive.");
        require(
            amountTokens <= token.balanceOf(msg.sender),
            "you dont have enough amount tokens."
        );

        uint amountETH = (amountTokens * eth_reserves) /
            (token_reserves + amountTokens);

        require(amountETH > 0, "too small");

        if (amountETH == eth_reserves) --amountETH;

        max_exchange_rate *= (10 ** 18);
        require(
            amountETH * multiplier <= amountTokens * max_exchange_rate,
            "change_rate > max_change_rate"
        );

        uint fee = (amountETH * swap_fee_numerator) / swap_fee_denominator;

        eth_fee_reserves += fee;

        token_reserves += amountTokens;
        eth_reserves -= amountETH;
        amountETH -= fee;

        token.transferFrom(msg.sender, address(this), amountTokens);
        payable(msg.sender).transfer(amountETH);
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate) external payable {
        /******* TODO: Implement this function *******/
        require(msg.value > 0, "amount must be a possitive.");

        uint amountETH = msg.value;
        uint amountTokens = (amountETH * token_reserves) /
            (eth_reserves + amountETH);

        require(amountTokens > 0, "too small");

        if (amountTokens == token_reserves) --amountTokens;

        max_exchange_rate *= (10 ** 18);
        require(
            amountETH * multiplier <= amountTokens * max_exchange_rate,
            "change_rate > max_change_rate"
        );

        uint fee = (amountTokens * swap_fee_numerator) / swap_fee_denominator;

        token_fee_reserves += fee;

        eth_reserves += amountETH;
        token_reserves -= amountTokens;
        amountTokens -= fee;

        token.transfer(msg.sender, amountTokens);
    }
}
