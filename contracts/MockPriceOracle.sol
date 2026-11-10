// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract MockPriceOracle {
    uint256 private ethPrice;

    constructor(uint256 _initialPrice){
        ethPrice = _initialPrice;
    }

    function getEthPrice() external view returns(uint256) {
        return ethPrice;
    }

    function setEthPrice(uint256 _newPrice) external {
        ethPrice = _newPrice;
    }
}