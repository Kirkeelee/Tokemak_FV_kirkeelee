import "./complexity.spec";
import "./vaultSummaries.spec";

// using LMPVault as Vault;
using BalancerAuraDestinationVault as BalancerDestVault;
using CurveConvexDestinationVault as CurveDestVault;
using SystemRegistry as systemRegistry;

methods {
    function _.getPriceInEth(address token) external with (env e) => getPriceInEthCVL[token][e.block.timestamp] expect (uint256);
    function _.getStats() external => DISPATCHER(true);
    function _.getValidatedSpotPrice() external => DISPATCHER(true);
    function _.isShutdown() external => DISPATCHER(true);
    function _.getPool() external => DISPATCHER(true);
    function _.getPriceOrZero(address, uint40) external => DISPATCHER(true);
    function _.underlying() external => DISPATCHER(true);
    function _.underlyingTokens() external => DISPATCHER(true);
    function _.debtValue(uint256) external => DISPATCHER(true);
    function _.getSpotPriceInEth(address, address) external => DISPATCHER(true);

    function _.getBptIndex() external => getBptIndexCVL expect (uint256);

    function violationTrackingState() external returns (uint8, uint8, uint16) envfree;
    function swapCostOffsetTightenThresholdInViolations() external returns (uint16) envfree;
    function swapCostOffsetMaxInDays() external returns (uint16) envfree;
    function swapCostOffsetMinInDays() external returns (uint16) envfree;
    function navTrackingState() external returns (uint8, uint8, uint40) envfree;
    function lastRebalanceTimestamp() external returns (uint40) envfree;
    function lmpVault() external returns (address) envfree;

    // harness functions
    // function getDestinationSummaryStatsExternal(address, uint256, LMPStrategy.RebalanceDirection, uint256) external returns (IStrategy.SummaryStats);
    function getSwapCostOffsetTightenThresholdInViolations() external returns (uint16) envfree;

    // function Vault.isDestinationRegistered(address) external returns (bool) envfree;
    // function Vault.isDestinationQueuedForRemoval(address) external returns (bool) envfree;
    // function Vault.asset() external returns (address) envfree;

    function BalancerDestVault.underlying() external returns (address) envfree;
    function CurveDestVault.underlying() external returns (address) envfree;

    // function LMPStrategy.getRebalanceInSummaryStats(IStrategy.RebalanceParams memory input) internal returns (IStrategy.SummaryStats memory) => getRebalanceInSummaryStatsCVL(input);

    function LMPStrategy.getDestinationSummaryStats(address destAddress,uint256 price,LMPStrategy.RebalanceDirection direction,uint256 amount) internal returns (IStrategy.SummaryStats memory) => getDestinationSummaryStatsCVL(destAddress, price, direction, amount);
    
    function LMPStrategy.getRebalanceValueStats(IStrategy.RebalanceParams memory input) internal returns (LMPStrategy.RebalanceValueStats memory) => getRebalanceValueStatsCVL(input);
}

/////// Functions

    function getRebalanceInSummaryStatsCVL(IStrategy.RebalanceParams input) returns IStrategy.SummaryStats {
        IStrategy.SummaryStats tmp;
        return tmp;
    }

    function getRebalanceValueStatsCVL(IStrategy.RebalanceParams input) returns LMPStrategy.RebalanceValueStats {
        LMPStrategy.RebalanceValueStats tmp;
        return tmp;
    }

    function getDestinationSummaryStatsCVL(address destAddress, uint256 price, LMPStrategy.RebalanceDirection direction, uint256 amount) returns IStrategy.SummaryStats {
        IStrategy.SummaryStats tmp;
        return tmp;
    }


// function getDestinationSummaryStatsCVL(
//     address destAddress,
//     uint256 price,
//     LMPStrategy.RebalanceDirection direction,
//     uint256 amount
// ) returns IStrategy.SummaryStats {
//     IStrategy.SummaryStats tmp;
//     require tmp.compositeReturn == compositeReturnGhost[destAddress][price][direction][amount];
//     return tmp;
// }

// ghost mapping(address => mapping(uint256 => mapping(LMPStrategy.RebalanceDirection => mapping(uint256 => int256)))) compositeReturnGhost;

use builtin rule sanity;

use rule privilegedOperation;

use rule 

ghost uint256 getBptIndexCVL;

ghost mapping(address => mapping(uint256 => uint256)) getPriceInEthCVL;


ghost uint16 _swapCostOffsetPeriodGhost;

hook Sload uint16 defaultValue _swapCostOffsetPeriod STORAGE {
    require _swapCostOffsetPeriodGhost == defaultValue;
}

hook Sstore _swapCostOffsetPeriod uint16 defaultValue STORAGE {
    _swapCostOffsetPeriodGhost = defaultValue;
}



ghost uint8 violationCountGhost;

ghost uint8 violationCountOldGhost;


hook Sstore currentContract.violationTrackingState.violationCount uint8 defaultValue 
    (uint8 defaultValue_old) STORAGE {
    violationCountGhost = defaultValue;
    violationCountOldGhost = defaultValue_old;
}




// STATUS - verified
// offset period should be between swapCostOffsetMaxInDays and swapCostOffsetMinInDays
invariant offsetIsInBetween()
    _swapCostOffsetPeriodGhost <= swapCostOffsetMaxInDays() && _swapCostOffsetPeriodGhost >= swapCostOffsetMinInDays();



// // STATUS - verified
// // if rebalance successful && strategy is paused => must be rebalance back to idle
// rule pausedStrategyVerifiesIdle(env e) {
//     IStrategy.RebalanceParams params;
//     IStrategy.SummaryStats outSummary;

//     bool pausedBefore = paused(e);
//     address destIn = params.destinationIn;

//     calldataarg args;
//     verifyRebalance@withrevert(e, params, outSummary);
//     bool isReverted = lastReverted;

//     assert pausedBefore && !isReverted => destIn == Vault;
// }



// // STATUS - verified
// // if rebalance successful && not rebalance to idle => not paused
// rule successfulNotPaused(env e) {
//     IStrategy.RebalanceParams params;
//     IStrategy.SummaryStats outSummary;

//     bool pausedBefore = paused(e);
//     address destIn = params.destinationIn;

//     calldataarg args;
//     verifyRebalance@withrevert(e, params, outSummary);
//     bool isReverted = lastReverted;

//     assert destIn != Vault && !isReverted => !pausedBefore;
// }

/*

// STATUS - verified
// violationTrackingState.len cant exceed 10
rule noVioLenThanTen(env e, method f) {
    uint8 lenBefore;
    uint8 lenAfter;
    
    _,lenBefore,_ = violationTrackingState();

    require lenBefore <= 10;

    calldataarg args;
    f(e, args);

    _,lenAfter,_ = violationTrackingState();

    assert lenAfter <= 10;
}



// STATUS - verified
// violationTrackingState.violationCount can be increased only by 1 at a time
rule cantJumpTwoViolationsAtOnce(env e, method f) {
    uint16 numOfViolationsBefore;
    numOfViolationsBefore,_,_ = violationTrackingState();

    calldataarg args;
    f(e, args);

    uint16 numOfViolationsAfter;
    numOfViolationsAfter,_,_ = violationTrackingState();

    assert numOfViolationsAfter - numOfViolationsBefore <= 1;
}


// STATUS - in progress
// violation count >= swapCostOffsetTightenThresholdInViolations  && current rebalance is also a violation => offset should decrease
rule violationCountAffectsOffset(env e, method f) {
    uint16 offsetPeriodBefore = _swapCostOffsetPeriodGhost;

    calldataarg args;
    f(e, args);

    uint8 violationsAfter; 
    violationsAfter,_,_= violationTrackingState();

    uint16 offsetPeriodAfter = _swapCostOffsetPeriodGhost;

    assert (require_uint16(violationCountGhost) > swapCostOffsetTightenThresholdInViolations()
                || require_uint16(violationCountOldGhost) > swapCostOffsetTightenThresholdInViolations())
             => offsetPeriodBefore > offsetPeriodAfter;
}



// STATUS - in progress
// offset period should be between swapCostOffsetMaxInDays and swapCostOffsetMinInDays
invariant offsetIsInBetween()
    _swapCostOffsetPeriodGhost <= swapCostOffsetMaxInDays() && _swapCostOffsetPeriodGhost >= swapCostOffsetMinInDays();





