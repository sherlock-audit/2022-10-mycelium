pragma solidity ^0.8.9;

import {DataTypes} from "../../src/vendors/aave/DataTypes.sol";
import "./Token.sol";
import "forge-std/console.sol";

contract StubLendingPool {
    Token public aLINK;
    Token public LINK;

    constructor(address _link) {
        LINK = Token(_link);
        aLINK = new Token("aLINK", "aLINK");
    }

    function getReserveData(address _token) public view returns (DataTypes.ReserveData memory) {
        return
            DataTypes.ReserveData({
                configuration: DataTypes.ReserveConfigurationMap(0),
                liquidityIndex: 0,
                variableBorrowIndex: 0,
                currentLiquidityRate: 0,
                currentVariableBorrowRate: 0,
                currentStableBorrowRate: 0,
                lastUpdateTimestamp: 0,
                aTokenAddress: address(aLINK),
                stableDebtTokenAddress: address(0),
                variableDebtTokenAddress: address(0),
                interestRateStrategyAddress: address(0),
                id: uint8(0)
            });
    }

    function deposit(
        address token,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) public {
        LINK.transferFrom(msg.sender, address(this), amount);
        aLINK.mint(onBehalfOf, amount);
    }

    function withdraw(
        address token,
        uint256 amount,
        address to
    ) public returns (uint256) {
        aLINK.burn(msg.sender, amount);
        LINK.transfer(to, amount);
        return amount;
    }
}
