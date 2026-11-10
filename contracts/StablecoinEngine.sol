// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./DUSD.sol";
import "./MockPriceOracle.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract StablecoinEngine is ReentrancyGuard {
    DUSD public immutable dusd;
    MockPriceOracle public immutable oracle;

    uint256 public constant COLLATERAL_RATIO = 150;   
    uint256 public constant UMBRAL_LIQUIDITY = 120;
    uint256 public constant BONUS_LIQUIDITY = 10;
    uint256 public constant PRECISION = 100;

    mapping(address => uint256) public collateralDeposited;    
    mapping(address => uint256) public dusdMinted;

    event CollateralDeposited(address indexed user, uint256 amount);
    event DUSDMinted(address indexed user, uint256 amount);
    event DUSDBurned(address indexed user, uint256 amount);
    event CollateralRedeemed(address indexed user, uint256 amount);
    event Liquidated(address indexed liquidator, address indexed user, uint256 debtCovered, uint256 collateralSeized);

    constructor(address _dusd, address _oracle){
        dusd = DUSD(_dusd);
        oracle = MockPriceOracle(_oracle);
    }

    function depositCollateral() external payable nonReentrant {
        require(msg.value > 0, "Amount must be > 0");
        collateralDeposited[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    function mintDUSD(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        dusdMinted[msg.sender] += amount;

        require(_getHealthFactor(msg.sender) >= COLLATERAL_RATIO, "Not enough collateral");

        dusd.mint(msg.sender, amount);
        emit DUSDMinted(msg.sender, amount);
    }

    function burnDUSD(uint256 amount) external nonReentrant{
        require(amount > 0, "Amount must be > 0");
        require(dusdMinted[msg.sender] >= amount, "Not enough debt");
        dusdMinted[msg.sender] -= amount;
        dusd.burn(msg.sender, amount);
        emit DUSDBurned(msg.sender, amount);
    }

    function redeemCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(collateralDeposited[msg.sender] >= amount, "Not enough collateral");
        
        collateralDeposited[msg.sender] -= amount;

        require(_getHealthFactor(msg.sender) >= COLLATERAL_RATIO || dusdMinted[msg.sender] == 0, "Position unhealthy");
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit CollateralRedeemed(msg.sender, amount);
    }

    function liquidity(address user, uint256 debtToCover) external nonReentrant {
        require(_getHealthFactor(user) < UMBRAL_LIQUIDITY, "Position is healthy");
        require(debtToCover > 0, "Debt to cover must be > 0");
        require(dusdMinted[user] >= debtToCover, "Debt too high");

        uint256 ethPrice = oracle.getEthPrice();
        uint256 collateralValueUsd = debtToCover;
        uint256 collateralAmount = (collateralValueUsd * 1e18) / ethPrice;
        uint256 bonusCollateral = (collateralAmount * BONUS_LIQUIDITY) / PRECISION;
        uint256 totalCollateralToSeize = collateralAmount + bonusCollateral;

        require(collateralDeposited[user] >= totalCollateralToSeize, "Not enough collateral to seize");

        dusdMinted[user] -= debtToCover;
        collateralDeposited[user] -= totalCollateralToSeize;

        dusd.burn(msg.sender, debtToCover);

        (bool success,) = msg.sender.call{value: totalCollateralToSeize}("");
        require(success, "Transfer failed");

        emit Liquidated(msg.sender, user, debtToCover, totalCollateralToSeize);
    }

    function _getHealthFactor(address user) internal view returns (uint256) {
        uint256 debt = dusdMinted[user];
        if(debt == 0) return type(uint256).max;
        uint256 collateralValueUsd = getCollateralValueInUsd(user);
        return (collateralValueUsd * PRECISION) / debt;
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _getHealthFactor(user);
    }

    function getCollateralValueInUsd(address user) public view returns (uint256){
        uint256 ethPrice = oracle.getEthPrice();
        return (collateralDeposited[user] * ethPrice) / 1e18;
    }
}