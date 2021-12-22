pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DEX {

    using SafeMath for uint256; // Adds .mult and .add etc to uint256
    IERC20 token;
    uint256 public totalLiquidity;
    mapping (address => uint256) public liquidityHolders; // TODO: Why?


    constructor(address tokenAddr) {
        token = IERC20(tokenAddr);
    }


    function init(uint256 numberOfTokens) public payable returns (uint256) {
        require(totalLiquidity ==0, "DEX:init - Cannot add liquidity if there is already liquidity");
        totalLiquidity = address(this).balance; // TODO: what
        liquidityHolders[msg.sender] = totalLiquidity;
        require(token.transferFrom(msg.sender, address(this), numberOfTokens));
        return totalLiquidity;
    }

    function tokenReserve() private returns (uint256) {
        return token.balanceOf(address(this));
    }

    function ethReserve() private returns (uint256) {
        return address(this).balance;
    }

    // Calculates the price (eth or token) that it will cost for inputAmount (eth or token) if there is a 0.3% fee
    // Price is based on the token & eth reserve and priced on a curve
    function price(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public view returns (uint256) {
        uint256 inputAmountWithFee = inputAmount.mul(997); // TODO: What?
        uint256 numerator = inputAmountWithFee.mul(outputReserve);
        uint256 denominator = inputReserve.mul(1000).add(inputAmountWithFee);
        return numerator / denominator;
    }

    function ethToToken() public payable returns (uint256) {
        // TODO: Why not use ethLiquidity?
        uint256 tokensBought = price(msg.value, ethReserve().sub(msg.value), tokenReserve());
        require(token.transfer(msg.sender, tokensBought));
        return tokensBought;
    }

    function tokenToEth(uint256 numberOfTokens) public returns (uint256) {
        uint256 ethBought = price(numberOfTokens, tokenReserve(), ethReserve());
        (bool sentStatus,) = msg.sender.call{value: ethBought}("");
        require(sentStatus, "Failed to send eth to user.");
        require(token.transferFrom(msg.sender, address(this), numberOfTokens));
        return ethBought;
    }

    // Receives ETH and also transfers tokens from the caller to the contract at the right ratio.
    function deposit() public payable returns (uint256) {
        uint256 newEthReserve = ethReserve().sub(msg.value);
        uint256 tokenAmount = (msg.value.mul(tokenReserve()) / newEthReserve).add(1); // TODO: What?
        uint256 liquidityMinted = msg.value.mul(totalLiquidity) / newEthReserve;
        liquidityHolders[msg.sender] = liquidityHolders[msg.sender].add(liquidityMinted);
        totalLiquidity = totalLiquidity.add(liquidityMinted);
        // Take the correct amount of tokens from the user based on the eth they deposit
        require(token.transferFrom(msg.sender, address(this), tokenAmount));
        return liquidityMinted;
    }

    // Lets a user take both ETH and tokens out at the correct ratio
    function withdraw(uint256 amount) public returns (uint256, uint256) {
        uint256 ethAmount = amount.mul(ethReserve() / totalLiquidity);
        uint256 tokenAmount = ethAmount.mul(address(this).balance) / totalLiquidity;
        liquidityHolders[msg.sender] = liquidityHolders[msg.sender].sub(ethAmount);
        totalLiquidity = totalLiquidity.sub(ethAmount);
        (bool sentStatus,) = msg.sender.call{value: ethAmount}("");
        require(sentStatus, "Failed to send user eth.");
        require(token.transfer(msg.sender, tokenAmount));
        return (ethAmount, tokenAmount);
    }

}
