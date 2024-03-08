using BalancerAuraDestinationVault as BalancerDestVault;
using CurveConvexDestinationVault as CurveDestVault;
using SystemRegistry as systemRegistry;

methods {
    /** Summaries **/
    
    // Base
    function _.getPriceInEth(address token) external with (env e) => getPriceInEthCVL[token][e.block.timestamp] expect (uint256);
    function _.getBptIndex() external => getBptIndexCVL expect (uint256);
    function _.current() external => NONDET;    
    // Vault
    // Summarized instead of linked to help with runtime. 
    // The two state changing functions don't change any relevant state and aren't implemented.
    // The rest of the functions are getters so ghost summary has the same effect as linking.
    function _.addToWithdrawalQueueHead(address) external => NONDET;
    function _.addToWithdrawalQueueTail(address) external => NONDET;
    function _.totalIdle() external => totalIdleCVL expect uint256;
    function _.asset() external => assetCVL expect address;
    function _.totalAssets() external => totalAssetsCVL expect uint256;
    function _.isDestinationRegistered(address dest) external => isDestinationRegisteredCVL[dest] expect bool;
    function _.isDestinationQueuedForRemoval(address dest) external => isDestinationQueuedForRemovalCVL[dest] expect bool;
    function _.getDestinationInfo(address dest) external => getDestinationInfoCVL(dest) expect LMPDebt.DestinationInfo;

    // ERC20's `decimals` summarized as 6, 8 or 18 (validDecimal), can be changed to ALWAYS(18) for better runtime.
    // This helps with runtime because arbitrary decimal value creates many nonlinear operations.
    function _.decimals() external => ALWAYS(18); // validDecimal expect uint256; // validDecimal is 6, 8 or 18 for a better summary

    // Can help reduce complexity, think carefully about implications before using.
    // May need to think of a more clever way to summarize this.
    //function LMPStrategy.getRebalanceValueStats(IStrategy.RebalanceParams memory input) internal returns (LMPStrategy.RebalanceValueStats memory); // => getRebalanceValueStatsCVL(input);
    
    /** Dispatchers **/
    // base
    function _.accessController() external => DISPATCHER(true); // needed in constructor, rest is handled by linking
    function _.getStats() external => DISPATCHER(true);
    function _.getValidatedSpotPrice() external => DISPATCHER(true);
    function _.isShutdown() external => DISPATCHER(true);
    function _.getPool() external => DISPATCHER(true);
    function _.getPriceOrZero(address, uint40) external => DISPATCHER(true);
    function _.underlying() external => DISPATCHER(true);
    function _.underlyingTokens() external => DISPATCHER(true);
    function _.debtValue(uint256) external => DISPATCHER(true);
    function _.getSpotPriceInEth(address, address) external => DISPATCHER(true);

    // ERC20
    function _.name() external => DISPATCHER(true);
    function _.symbol() external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.allowance(address,address) external => DISPATCHER(true);
    function _.approve(address,uint256) external => DISPATCHER(true);
    function _.transfer(address,uint256) external => DISPATCHER(true);
    function _.transferFrom(address,address,uint256) external => DISPATCHER(true);

    /** Envfree **/
    // Base
    function violationTrackingState() external returns (uint8, uint8, uint16) envfree;
    function navTrackingState() external returns (uint8, uint8, uint40) envfree;
    function swapCostOffsetMaxInDays() external returns (uint16) envfree;
    function swapCostOffsetMinInDays() external returns (uint16) envfree;
    // Harnessed
    function getDestinationSummaryStatsExternal(address, uint256, LMPStrategy.RebalanceDirection, uint256) external returns (IStrategy.SummaryStats);
    function getSwapCostOffsetTightenThresholdInViolations() external returns (uint16) envfree;
    

    
}

function getParams() returns IStrategy.RebalanceParams {
    IStrategy.RebalanceParams tmp;
    return tmp;
}

function getOutSummary() returns IStrategy.SummaryStats {
    IStrategy.SummaryStats tmp;
    return tmp;
}

function getnavTrackingState() returns NavTracking.State {
    NavTracking.State tmp;
    return tmp;
}


function getRebalanceDirection() returns LMPStrategy.RebalanceDirection {
    LMPStrategy.RebalanceDirection tmp;
    return tmp;
}
/** Functions **/
// For base summaries
/*
function getRebalanceValueStatsCVL(IStrategy.RebalanceParams input) returns LMPStrategy.RebalanceValueStats {
    LMPStrategy.RebalanceValueStats tmp;
    return tmp;
} */

// For vault summaries
function getDestinationInfoCVL(address dest) returns LMPDebt.DestinationInfo {
    LMPDebt.DestinationInfo info;
    return info;
}

function currentCVL() returns IDexLSTStats.DexLSTStatsData {
    IDexLSTStats.DexLSTStatsData data;
    return data;
}

definition DAY() returns uint40 = 86400;

/** Ghosts and Hooks **/
// For base summaries
ghost uint256 getBptIndexCVL;
ghost uint256 validDecimal {
    axiom validDecimal == 6 || validDecimal == 8 || validDecimal == 18;
}
ghost mapping(address => mapping(uint256 => uint256)) getPriceInEthCVL;

// For vault summaries
ghost uint256 totalIdleCVL;
ghost address assetCVL;
ghost uint256 totalAssetsCVL;

ghost mapping(address => bool) isDestinationRegisteredCVL;
ghost mapping(address => bool) isDestinationQueuedForRemovalCVL;

// For properties
ghost uint16 _swapCostOffsetPeriodGhost;

hook Sload uint16 defaultValue _swapCostOffsetPeriod STORAGE {
    require _swapCostOffsetPeriodGhost == defaultValue;
}

hook Sstore _swapCostOffsetPeriod uint16 defaultValue STORAGE {
    _swapCostOffsetPeriodGhost = defaultValue;
}

/** Properties **/

use builtin rule sanity;

// Offset period must be between swapCostOffsetMaxInDays and swapCostOffsetMinInDays.
invariant offsetIsInBetween()
    _swapCostOffsetPeriodGhost <= swapCostOffsetMaxInDays() && _swapCostOffsetPeriodGhost >= swapCostOffsetMinInDays();


// `violationTrackingState.violationCount` must not be increased by more than 1
rule cantJumpTwoViolationsAtOnce(env e, method f) {
    uint16 numOfViolationsBefore;
    numOfViolationsBefore,_,_ = violationTrackingState();

    calldataarg args;
    f(e, args);

    uint16 numOfViolationsAfter;
    numOfViolationsAfter,_,_ = violationTrackingState();

    assert numOfViolationsAfter - numOfViolationsBefore <= 1;
}

//rule for checking the revert conditions on function Verifyrebalance()
rule revertingconditionsVerifyrebalance (env e) {
    uint256 inPrice;
    LMPStrategy.RebalanceDirection RebalanceDirection = getRebalanceDirection();
    IStrategy.RebalanceParams params = getParams();
    IStrategy.SummaryStats outSummary = getOutSummary();
    IStrategy.SummaryStats inSummary = getDestinationSummaryStatsExternal(e, params.destinationIn, inPrice, LMPStrategy.RebalanceDirection.In, params.amountIn);
    uint256 tolerance = getlstPriceGapTolerance(e);
    require tolerance !=0;
    address lmpVault = getlmpVault(e);
    require lmpVault != params.destinationIn;
    int256 maxDiscount = getmaxDiscount(e);
    int256 maxPremium = getmaxPremium(e);
    

    
    bool paused = paused(e); 
    bool verifypricegap = verifyLSTPriceGapExternal(e, params, tolerance);

    verifyRebalance@withrevert(e, params, outSummary);
   
    assert paused || !verifypricegap || inSummary.maxDiscount > maxDiscount ||(assert_int256(-inSummary.maxPremium) > maxPremium) => lastReverted;
}

rule revertingConditionsValidateParams (env e) {
    IStrategy.RebalanceParams params = getParams();
    IStrategy.SummaryStats outSummary = getOutSummary();


    bool DStInRegistered = isDestinationRegisteredCVL[params.destinationIn];
    bool DStOutRegistered = isDestinationRegisteredCVL[params.destinationOut];
    address lmpVault = getlmpVault(e);
    require lmpVault != params.destinationIn && lmpVault != params.destinationOut;

   
      
    verifyRebalance@withrevert(e, params, outSummary);

       
    assert params.destinationIn == 0 || params.destinationOut == 0 || 
    params.tokenIn == 0 || params.tokenOut == 0 || params.amountIn == 0 || params.amountOut == 0 || !DStInRegistered || 
    !DStOutRegistered => lastReverted;
}


rule revertingConditionsValidateParams2 (env e) {
    IStrategy.RebalanceParams params = getParams();
    IStrategy.SummaryStats outSummary = getOutSummary();


    address lmpVault = getlmpVault(e);
    require lmpVault != params.destinationIn && lmpVault != params.destinationOut;
    address baseAsset = assetCVL;

   
      
    verifyRebalance@withrevert(e, params, outSummary);

       
    assert params.destinationIn == params.destinationOut || params.destinationIn == lmpVault && params.tokenIn != baseAsset ||
    params.destinationOut == lmpVault && params.tokenIn != baseAsset || params.destinationOut == lmpVault && params.amountOut > totalIdleCVL => lastReverted;

}

rule rebalanceSuccess (env e) {

    IStrategy.RebalanceParams params = getParams();
    address lmpVault = getlmpVault(e);

    require params.destinationIn != lmpVault;

    rebalanceSuccessfullyExecuted(e, params);

    uint40 NewRebalance = getlastRebalanceTimestamp(e);


    assert NewRebalance == require_uint40 (e.block.timestamp);

}


rule revertingconditionsVerifyToIdle (env e) {
    IStrategy.RebalanceParams params = getParams();
    IStrategy.SummaryStats outSummary = getOutSummary();
    LMPStrategy.RebalanceValueStats  valueStats = getRebalanceValueStatsExternal(e, params);
    address lmpVault = getlmpVault(e);
    require lmpVault == params.destinationIn;
    uint256 maxShutdownOperationSlippage = getmaxShutdownOperationSlippage(e);
    uint256 maxEmergencyOperationSlippage = getmaxEmergencyOperationSlippage(e);
    uint256 maxTrimOperationSlippage = getmaxTrimOperationSlippage(e);
    uint256 maxNormalOperationSlippage = getmaxNormalOperationSlippage(e);
    require valueStats.slippage > maxEmergencyOperationSlippage && valueStats.slippage > maxShutdownOperationSlippage &&
    valueStats.slippage > maxNormalOperationSlippage && valueStats.slippage > maxTrimOperationSlippage;
    bool isDestinationQueuedForRemoval = isDestinationQueuedForRemovalCVL[params.destinationOut];
    require isDestinationQueuedForRemoval == true;
    uint256 staleDataToleranceInSecond = require_uint256(getstaleDataToleranceInSeconds(e));
    uint256 dataTimestamp;
    require staleDataToleranceInSecond >= require_uint256(e.block.timestamp - dataTimestamp);

    verifyRebalance@withrevert(e, params, outSummary);


    
    assert valueStats.slippage > maxShutdownOperationSlippage || valueStats.slippage > maxEmergencyOperationSlippage ||
    valueStats.slippage > maxTrimOperationSlippage || valueStats.slippage > maxNormalOperationSlippage => lastReverted;
}

rule NoChangetolastRebalanceTimestamp(env e, method f) filtered {
   f -> f.selector != sig:rebalanceSuccessfullyExecuted(IStrategy.RebalanceParams).selector
   }{
  
   uint40 OldRebalance = getlastRebalanceTimestamp(e);
   calldataarg args;
   f(e, args);

   uint40 NewRebalance = getlastRebalanceTimestamp(e);

   assert NewRebalance == OldRebalance;

}



rule succesfullNavUpdate (env e, uint256 navPerShare) {
   

   uint40 FinalizedBefore;
   uint40 FinalizedAfter;

   _,_,FinalizedBefore = navTrackingState();
   

   navUpdate(e, navPerShare);

   _,_,FinalizedAfter = navTrackingState();
    

   assert FinalizedBefore <= FinalizedAfter;


}

rule NoChangeToNavparams (env e, method f) filtered {
   f -> f.selector != sig:navUpdate(uint256).selector
   }{
   

   uint40 FinalizedBefore;
   uint40 FinalizedAfter;
   uint8 lenBefore;
   uint8 lenAfter;
   uint8 currentIndexBefore;
   uint8 currentIndexAfter;

   lenBefore,currentIndexBefore,FinalizedBefore = navTrackingState();
   

   calldataarg args;
   f(e, args);

   lenAfter,currentIndexAfter,FinalizedAfter = navTrackingState();
    

   assert FinalizedBefore == FinalizedAfter;
   assert lenBefore == lenAfter;
   assert currentIndexBefore == currentIndexAfter;



}

