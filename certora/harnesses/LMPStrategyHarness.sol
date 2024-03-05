// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import "../../src/strategy/LMPStrategy.sol";
contract LMPStrategyHarness is LMPStrategy{
    constructor(
        ISystemRegistry _systemRegistry,
        address _lmpVault,
        LMPStrategyConfig.StrategyConfig memory conf
    ) LMPStrategy(_systemRegistry, _lmpVault, conf) {}
    
    function getDestinationSummaryStatsExternal(address destAddress, uint256 price, RebalanceDirection direction, uint256 amount) external returns (IStrategy.SummaryStats memory){
        return getDestinationSummaryStats(destAddress, price, direction, amount);
    }
    function verifyLSTPriceGapExternal(IStrategy.RebalanceParams memory params, uint256 tolerance) external returns (bool) {
        return verifyLSTPriceGap (params, tolerance);
    }

    function getSwapCostOffsetTightenThresholdInViolations() external returns (uint16){
        return swapCostOffsetTightenThresholdInViolations;
    }
    
     function getlstPriceGapTolerance() external returns (uint256){
        return lstPriceGapTolerance;
    }

    function getlastPausedTimestamp() external returns (uint40){
        return lastPausedTimestamp;
    }

     function getlmpVault() external returns (ILMPVault){
        return lmpVault;
    }

     function getmaxDiscount() external returns (int256){
        return maxDiscount;
    }

      function getmaxPremium() external returns (int256){
        return maxPremium;
    }
} 